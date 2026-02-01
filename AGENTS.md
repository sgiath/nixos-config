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

| System | Purpose |
|--------|---------|
| ceres | **Primary** - Main daily desktop/gaming workstation (AMD GPU, Steam). Default configuration. |
| pallas | Notebook, used occasionally |
| vesta | Home lab server |
| hygiea | Decommissioned (was offsite server) |

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
- Always include `update.sh` script for version updates (see `packages/openwork/update.sh` for reference)
- Remember to `git add` new package files before Nix can see them
- Follow the existing pattern: `packages/<name>/default.nix` + entry in `packages/default.nix`
