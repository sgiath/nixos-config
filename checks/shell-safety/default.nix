# `nix flake check`: every tracked `*.sh` script with a shebang passes
# shellcheck, including the optional checks for masked exit statuses, and the
# fixtures still fail. Scripts without a shebang are fragments that Nix
# builders embed (writeShellApplication checks those itself).
{
  lib,
  runCommand,
  shellcheck,
}:

let
  fixtures = ./fixtures;
  scripts = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.difference (lib.fileset.fileFilter (file: file.hasExt "sh") ../..) fixtures;
  };
in
runCommand "shell-safety" { nativeBuildInputs = [ shellcheck ]; } ''
  flags=(--external-sources --enable=check-extra-masked-returns,check-set-e-suppressed)

  cd ${scripts}
  find . -name '*.sh' -type f -exec awk 'FNR == 1 && /^#!/ { print FILENAME } { nextfile }' {} + \
    | sort >"$TMPDIR/scripts"
  mapfile -t scripts <"$TMPDIR/scripts"
  if ((''${#scripts[@]} == 0)); then
    echo "shell-safety: no scripts found" >&2
    exit 1
  fi
  echo "shell-safety: checking ''${#scripts[@]} scripts"
  shellcheck "''${flags[@]}" "''${scripts[@]}"

  # Each fixture reproduces a script that reported success after a failed
  # command; the check must keep rejecting it.
  for fixture in ${fixtures}/*.sh; do
    if shellcheck "''${flags[@]}" "$fixture" >"$TMPDIR/fixture.log"; then
      echo "shell-safety: fixture $(basename "$fixture") passed but must fail" >&2
      exit 1
    fi
    if ! grep -q SC2312 "$TMPDIR/fixture.log"; then
      cat "$TMPDIR/fixture.log" >&2
      echo "shell-safety: fixture $(basename "$fixture") must fail with SC2312" >&2
      exit 1
    fi
  done

  touch $out
''
