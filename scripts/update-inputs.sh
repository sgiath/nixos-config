#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLAKE_NIX="${REPO_DIR}/flake.nix"
PACKAGES_DIR="${REPO_DIR}/packages"
DRY_RUN=0
RUN_PACKAGE_UPDATERS=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--no-packages]

Updates GitHub flake inputs in flake.nix whose refs look like release tags
to each repository's latest GitHub release tag, then runs package update scripts
from packages/*/update.sh, builds every package they changed, and bumps the
Executor container image (scripts/update-executor.sh). Exits non-zero when a
changed package fails to build.

Put one of these comments immediately above an input to pin it instead:
  # pin to v1.2.3
  # flake-release-pin: v1.2.3

Options:
  --dry-run      Show what would change; do not edit files, open URLs, or run package scripts
  --no-packages  Skip packages/*/update.sh scripts and package builds
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN=1
    ;;
  --no-packages)
    RUN_PACKAGE_UPDATERS=0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd gh
require_cmd jq

# Nix access-tokens only apply to Nix fetches. Prefetch helpers and child
# update.sh scripts look at GITHUB_TOKEN / GH_TOKEN instead.
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  if [[ -n "${GH_TOKEN:-}" ]]; then
    export GITHUB_TOKEN="${GH_TOKEN}"
  elif [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    export GITHUB_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}"
  elif token="$(gh auth token 2>/dev/null)" && [[ -n "${token}" ]]; then
    export GITHUB_TOKEN="${token}"
  fi
fi
if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  export GH_TOKEN="${GITHUB_TOKEN}"
fi
if [[ ! -f "${FLAKE_NIX}" ]]; then
  echo "ERROR: ${FLAKE_NIX} does not exist" >&2
  exit 1
fi

RELEASE_REF_RE='^v?[0-9]+([._-][0-9A-Za-z]+)*$'

latest_release_tag() {
  local repo="$1"

  gh api "repos/${repo}/releases/latest" --jq .tag_name
}

open_latest_release_page() {
  local repo="$1"
  local url="https://github.com/${repo}/releases/latest"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "    Would open ${url}"
    return
  fi

  if ! command -v xdg-open >/dev/null 2>&1; then
    echo "WARNING: xdg-open not found; could not open ${url}" >&2
    return
  fi

  echo "    Opening ${url}"
  if ! xdg-open "${url}" >/dev/null 2>&1; then
    echo "WARNING: xdg-open failed for ${url}" >&2
  fi
}

# Content of a package directory as Nix flake evaluation sees it: tracked and
# untracked-but-not-ignored files, so `result` links and dirty trees are fine.
# Deleted tracked files appear in both listings; `uniq -zu` drops them.
package_fingerprint() {
  (
    cd "${REPO_DIR}"
    {
      git ls-files -z -co --deduplicate --exclude-standard -- "packages/$1"
      git ls-files -z -d -- "packages/$1"
    } | sort -z | uniq -zu | xargs -0r sha256sum | sha256sum
  )
}

# Prints `<attr> <dir>` for every `<attr> = pkgs.callPackage ./<dir> { };`.
registered_packages() {
  sed -nE 's#^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*pkgs\.callPackage[[:space:]]+\./([A-Za-z0-9_-]+).*#\1 \2#p' \
    "${PACKAGES_DIR}/default.nix"
}

# Builds each registered package whose directory changed, or whose directory
# references a changed one (`../<dir>/`, e.g. t3code-nightly-desktop reads
# t3code-nightly/sources.json). Records failed builds in FAILED_BUILDS.
build_changed_packages() {
  local -n before="$1"
  local -a changed_dirs=()
  local -a targets=()
  local dir attr pkg_dir changed fingerprint registered

  for dir in "${!before[@]}"; do
    fingerprint="$(package_fingerprint "${dir}")"
    if [[ "${fingerprint}" != "${before[${dir}]}" ]]; then
      changed_dirs+=("${dir}")
    fi
  done
  if [[ "${#changed_dirs[@]}" -eq 0 ]]; then
    echo "==> No package directories changed; nothing to build"
    return 0
  fi

  registered="$(registered_packages)"
  while read -r attr pkg_dir; do
    for changed in "${changed_dirs[@]}"; do
      if [[ "${pkg_dir}" == "${changed}" ]] ||
        grep -rqF --include='*.nix' "../${changed}/" "${PACKAGES_DIR}/${pkg_dir}"; then
        targets+=("${attr}")
        break
      fi
    done
  done <<<"${registered}"
  if [[ "${#targets[@]}" -eq 0 ]]; then
    echo "==> Changed directories ${changed_dirs[*]} map to no registered package"
    return 0
  fi

  echo "==> Building ${#targets[@]} updated packages: ${targets[*]}"
  for attr in "${targets[@]}"; do
    echo "==> ${attr}: nix build '.#${attr}'"
    if ! nix build --no-link "${REPO_DIR}#${attr}"; then
      FAILED_BUILDS+=("${attr}")
      echo "ERROR: ${attr}: build failed after update" >&2
    fi
  done

  if [[ "${#FAILED_BUILDS[@]}" -eq 0 ]]; then
    echo "==> All ${#targets[@]} updated packages build"
  fi
}

run_package_updaters() {
  if [[ "${RUN_PACKAGE_UPDATERS}" -eq 0 ]]; then
    echo "==> Skipping package update scripts"
    return
  fi

  if [[ ! -d "${PACKAGES_DIR}" ]]; then
    echo "==> No packages directory found; skipping package update scripts"
    return
  fi

  local package_dir
  local package_name
  local package
  local status
  local script
  local -a package_scripts=()
  local -a failed_packages=()
  local -a succeeded_packages=()
  for script in "${PACKAGES_DIR}"/*/update.sh; do
    if [[ -f "${script}" ]]; then
      package_scripts+=("${script}")
    fi
  done
  if [[ "${#package_scripts[@]}" -eq 0 ]]; then
    echo "==> No package update scripts found"
    return
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "==> Would run ${#package_scripts[@]} package update scripts"
    for script in "${package_scripts[@]}"; do
      package_name="$(basename "$(dirname "${script}")")"
      echo "    ${package_name}: ${script}"
    done
    return
  fi

  local dir
  local -A fingerprints=()
  for dir in "${PACKAGES_DIR}"/*/; do
    dir="$(basename "${dir}")"
    # shellcheck disable=SC2034 # read through build_changed_packages' nameref
    fingerprints["${dir}"]="$(package_fingerprint "${dir}")"
  done

  echo "==> Running ${#package_scripts[@]} package update scripts"
  for script in "${package_scripts[@]}"; do
    package_dir="$(dirname "${script}")"
    package_name="$(basename "${package_dir}")"
    echo "==> ${package_name}: running update.sh"
    if (cd "${package_dir}" && ./update.sh); then
      succeeded_packages+=("${package_name}")
      echo "==> ${package_name}: update.sh complete"
    else
      status=$?
      failed_packages+=("${package_name} (${status})")
      echo "ERROR: ${package_name}: update.sh failed with exit ${status}; continuing" >&2
    fi
    echo
  done

  echo "==> Package update scripts complete: ${#succeeded_packages[@]} succeeded, ${#failed_packages[@]} failed"
  if [[ "${#failed_packages[@]}" -gt 0 ]]; then
    echo "==> Failed package update scripts:"
    for package in "${failed_packages[@]}"; do
      echo "    ${package}"
    done
  fi
  echo

  build_changed_packages fingerprints
}

FAILED_BUILDS=()

finish() {
  run_package_updaters
  echo "==> Updating Executor image"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    "${SCRIPT_DIR}/update-executor.sh" --dry-run
  else
    "${SCRIPT_DIR}/update-executor.sh"
  fi
  if [[ "${#FAILED_BUILDS[@]}" -gt 0 ]]; then
    echo "ERROR: updated packages failed to build: ${FAILED_BUILDS[*]}" >&2
    exit 1
  fi
  echo "==> Done"
}

declare -a INPUTS=()
declare -a REPOS=()
declare -a CURRENT_REFS=()
declare -a TARGET_REFS=()
declare -a PINNED_REFS=()
declare -a CHANGED_INPUTS=()

in_inputs=0
current_input=""
pending_pin=""
while IFS= read -r line; do
  if [[ "${in_inputs}" -eq 0 ]]; then
    if [[ "${line}" =~ ^[[:space:]]*inputs[[:space:]]*=[[:space:]]*\{ ]]; then
      in_inputs=1
    fi
    continue
  fi

  if [[ "${line}" =~ ^[[:space:]]{2}\}\; ]]; then
    break
  fi

  if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*pin[[:space:]]+to[[:space:]]+([^[:space:]]+) ]]; then
    pending_pin="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*flake-release-pin:[[:space:]]*([^[:space:]]+) ]]; then
    pending_pin="${BASH_REMATCH[1]}"
    continue
  fi

  if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*\{ ]]; then
    current_input="${BASH_REMATCH[1]}"
  fi

  input_name=""
  url=""
  if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9_-]+)\.url[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
    input_name="${BASH_REMATCH[1]}"
    url="${BASH_REMATCH[2]}"
  elif [[ -n "${current_input}" && "${line}" =~ ^[[:space:]]*url[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
    input_name="${current_input}"
    url="${BASH_REMATCH[1]}"
  fi

  if [[ "${url}" =~ ^github:([^/]+)/([^/]+)/([^/?#]+)$ ]]; then
    repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    ref="${BASH_REMATCH[3]}"
    if [[ "${ref}" =~ ${RELEASE_REF_RE} ]]; then
      INPUTS+=("${input_name}")
      REPOS+=("${repo}")
      CURRENT_REFS+=("${ref}")
      PINNED_REFS+=("${pending_pin}")
      pending_pin=""
    fi
  elif [[ -n "${url}" ]]; then
    pending_pin=""
  fi
done <"${FLAKE_NIX}"

if [[ "${#INPUTS[@]}" -eq 0 ]]; then
  echo "==> No GitHub flake inputs with release-like refs found"
  finish
  exit 0
fi

echo "==> Checking ${#INPUTS[@]} release-pinned flake inputs"
for i in "${!INPUTS[@]}"; do
  input="${INPUTS[$i]}"
  repo="${REPOS[$i]}"
  current_ref="${CURRENT_REFS[$i]}"
  pinned_ref="${PINNED_REFS[$i]}"

  echo "==> ${input}: checking ${repo}"
  latest_ref="$(latest_release_tag "${repo}")"
  if [[ -z "${latest_ref}" || "${latest_ref}" == "null" ]]; then
    echo "ERROR: could not resolve latest release tag for ${repo}" >&2
    exit 1
  fi

  if [[ -n "${pinned_ref}" ]]; then
    if [[ ! "${pinned_ref}" =~ ${RELEASE_REF_RE} ]]; then
      echo "ERROR: ${input} has invalid pin ref: ${pinned_ref}" >&2
      exit 1
    fi

    TARGET_REFS+=("${pinned_ref}")
    if [[ "${latest_ref}" == "${pinned_ref}" ]]; then
      echo "    Pinned to ${pinned_ref}; latest release is unchanged"
    else
      echo "    Pinned to ${pinned_ref}; latest release is ${latest_ref}"
      open_latest_release_page "${repo}"
    fi

    if [[ "${pinned_ref}" == "${current_ref}" ]]; then
      :
    else
      echo "    Applying pin: ${current_ref} -> ${pinned_ref}"
      CHANGED_INPUTS+=("${input}")
    fi
  else
    TARGET_REFS+=("${latest_ref}")

    if [[ "${latest_ref}" == "${current_ref}" ]]; then
      echo "    Already at ${current_ref}"
    else
      echo "    ${current_ref} -> ${latest_ref}"
      open_latest_release_page "${repo}"
      CHANGED_INPUTS+=("${input}")
    fi
  fi
  echo
done

if [[ "${#CHANGED_INPUTS[@]}" -eq 0 ]]; then
  echo "==> No flake input refs need updating"
  finish
  exit 0
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "==> Would update flake inputs:"
  for input in "${CHANGED_INPUTS[@]}"; do
    echo "    ${input}"
  done
  finish
  exit 0
fi

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT
cp "${FLAKE_NIX}" "${tmp_file}"

for i in "${!INPUTS[@]}"; do
  current_ref="${CURRENT_REFS[$i]}"
  target_ref="${TARGET_REFS[$i]}"
  if [[ "${current_ref}" == "${target_ref}" ]]; then
    continue
  fi

  # shellcheck disable=SC2016 # $ is a literal regex metacharacter
  repo_escaped="$(printf '%s' "${REPOS[$i]}" | sed 's/[.[\*^$()+?{}|\\/]/\\&/g')"
  # shellcheck disable=SC2016 # $ is a literal regex metacharacter
  current_escaped="$(printf '%s' "${current_ref}" | sed 's/[.[\*^$()+?{}|\\/]/\\&/g')"
  perl -0pi -e 's#github:'"${repo_escaped}"'/'"${current_escaped}"'([\"?])#github:'"${REPOS[$i]}"'/'"${target_ref}"'$1#g' "${tmp_file}"
done

mv "${tmp_file}" "${FLAKE_NIX}"
trap - EXIT

finish
