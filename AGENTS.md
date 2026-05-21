# NixOS configuration

Personal NixOS configuration using **Snowfall Lib** framework for organization. Manages 3 systems (ceres, pallas, vesta) with shared modules and per-system customizations.

## Commands

```bash
# Rebuild and switch current system
nixos-rebuild switch --sudo --flake .

# Update flake lockfile
nix flake update

# Format Nix code
nixfmt <file.nix>

# Enter development shell
nix develop

# Build specific package
nix build ".#ntm"
```

**Important**: Nix flakes only see files tracked by git. When creating new files (packages, modules, etc.), you must `git add` them before Nix can evaluate them.

Custom shell scripts are available after system build: `update`, `update-limited`, `upgrade`, `clear-cache`.

## Architecture

### Snowfall Lib Structure

The flake uses `snowfall-lib` with namespace `sgiath`. Directory structure follows Snowfall conventions:

- `systems/x86_64-linux/<hostname>/` - Per-system NixOS configurations
- `homes/x86_64-linux/<user>@<hostname>/` - Per-user home-manager configurations
- `modules/nixos/` - Reusable NixOS modules
- `modules/home/` - Reusable home-manager modules
- `packages/` - Custom package definitions
- `overlays/` - Nixpkgs overlays
- `shells/` - Development shell environments
- `lib/` - Custom library functions

### Module Organization

**NixOS modules** (`modules/nixos/`):

- `sgiath/` - Personal system modules (boot, networking, GPU drivers, desktop, Docker, etc.)
- `server/` - Server services (Matrix, nginx, Plex, GitLab, Minecraft, etc.)
- `crazyegg/` - Additional configuration group

**Home modules** (`modules/home/`):

- `sgiath/` - User configuration (Hyprland, Neovim, shells, applications)
- `sgiath/targets/` - Configuration profiles (graphical, terminal)
- `crazyegg/` - AWS-related configuration

### Systems

| System | Purpose                                                                                      |
| ------ | -------------------------------------------------------------------------------------------- |
| ceres  | **Primary** - Main daily desktop/gaming workstation (AMD GPU, Steam). Default configuration. |
| pallas | Notebook, used occasionally                                                                  |
| vesta  | Home lab server                                                                              |
| hygiea | Decommissioned (was offsite server)                                                          |

### Module Enable Pattern

Modules use a standard enable pattern:

```nix
options.feature.enable = lib.mkEnableOption "feature name";
config = lib.mkIf config.feature.enable { /* configuration */ };
```

### Secrets

Secrets are stored in `secrets.json` (encrypted with git-crypt) and loaded via `builtins.fromJSON`.

### Multi-Channel Nixpkgs

Three nixpkgs channels available via overlays:

- `nixpkgs-master` - Latest master branch
- `nixpkgs` - Unstable channel
- `nixpkgs-stable` - 24.11 stable

## Key Files

- `flake.nix` - Main flake with 30+ inputs
- `modules/home/sgiath/default.nix` - Main user module, defines custom shell scripts
- `modules/nixos/sgiath/default.nix` - Main system module aggregator
- `overlays/sgiath/default.nix` - Package overrides from different sources

## Package Guidelines

When creating new packages in `packages/`:

- Always include an executable `update.sh` script for version updates. Use nearby package scripts as references.
- Remember to `git add` new package files before Nix can see them
- Follow the existing pattern: `packages/<name>/default.nix` + entry in `packages/default.nix`
- **Never delete the `result` symlink** - leave it for the user to manage

### Update Script Pattern

Package update scripts should behave consistently:

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Do not use `nix-shell` shebangs. If an update script needs extra tools, add them to `shells/default/default.nix` so they are available through `nix develop`
- Define `SCRIPT_DIR` and `DEFAULT_NIX` so the script works from any current directory
- Accept an optional version argument when the upstream has stable versions/tags; otherwise fetch latest metadata
- Print what is being fetched, then print `Latest version: <version>` after resolving the target version
- Read the current version from `default.nix`
- If the target version equals the current version, print `==> Already at version <version>, nothing to do` and exit before prefetching or rewriting files
- If updating, print `==> Updating from <current> to <target>`
- Only after the version changed, compute source hashes, binary hashes, vendor hashes, npm dependency hashes, lockfiles, or other expensive generated data
- Update `default.nix` and any generated lockfiles in place
- Finish with a clear success message and concrete next steps, usually `nix build '.#<package>'` and commit changes

Use this skeleton for new scripts:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
  VERSION="${1#v}"
  echo "==> Updating <package> to specified version ${VERSION}"
else
  echo "==> Fetching latest <package> version from <upstream>..."
  VERSION="<fetch latest version>"
  echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
  echo "==> Already at version ${VERSION}, nothing to do"
  exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

# Fetch metadata, prefetch hashes, update lockfiles, then rewrite default.nix.

echo "==> Done! Updated <package> to ${VERSION}"
echo "Next step: nix build '.#<package>'"
```

<!-- BACKLOG.MD MCP GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_backlog_instructions()` to load the tool-oriented overview. Use the `instruction` selector when you need `task-creation`, `task-execution`, or `task-finalization`.

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->
