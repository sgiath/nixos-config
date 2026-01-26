{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./agents.nix
    ./audio.nix
    ./bitcoin.nix
    ./chromium.nix
    # ./clawdbot.nix
    ./clipboard.nix
    ./comm.nix
    ./editors.nix
    ./email_client.nix
    ./file-explorer.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./stylix.nix
    ./tmux.nix
    ./wallpaper.nix
    ./waybar.nix
    ./web_browsers.nix
    ./zsh.nix

    ./targets
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    home = {
      stateVersion = "23.11";

      packages = with pkgs; [
        (writeShellScriptBin "update" ''
          pushd ~/nixos

          git add --all
          git commit --signoff -m "changes"
          git push

          case "$1" in
            --ceres)
              nixos-rebuild switch --sudo --flake '.#ceres'
              ;;

            --vesta)
              nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-Linux-13.350.zip
              nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'sgiath@vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --sudo --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --sudo --flake .
              ;;
          esac

          popd
        '')

        (writeShellScriptBin "update-limited" ''
          pushd ~/nixos

          git add --all
          git commit --signoff -m "changes"
          git push

          case "$1" in
            --ceres)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#ceres'
              ;;

            --vesta)
              nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-Linux-13.351.zip
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#vesta' --target-host 'sgiath@vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake .
              ;;
          esac

          popd
        '')

        (writeShellScriptBin "upgrade" ''
          pushd ~/nixos

          git add --all
          git commit --signoff -m "changes"

          nix flake update
          git add --all
          git commit --signoff -m "flake update"
          git push

          popd
        '')

        (writeShellScriptBin "fix-images" ''
          find . -type f \( \
            -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \
            -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.heic" \
            -o -iname "*.heif" \) -print0 | \
          ${parallel-full}/bin/parallel -0 --eta \
            exiftool -quiet -api PNGEarlyXMP=1 -JUMBF:all= -overwrite_original {}
        '')

        (writeShellScriptBin "clear-cache" ''
          doas nix-collect-garbage -d
          nix-collect-garbage -d

          doas nix-store --gc
          doas nix-store --optimise
        '')

        (writeShellScriptBin "gw" ''
          set -euo pipefail

          if [[ $# -lt 1 ]]; then
            echo "Usage: gw <branch-name>"
            echo ""
            echo "Creates a git worktree"
            exit 1
          fi

          branch="$1"
          repo_root=$(dirname "$(git rev-parse --git-common-dir)")
          worktree_dir="$repo_root/$branch"

          # Check if branch exists locally or remotely
          if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "Creating worktree for existing local branch: $branch"
            git worktree add "$worktree_dir" "$branch"
          elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            echo "Creating worktree for remote branch: $branch"
            git worktree add "$worktree_dir" "$branch"
          else
            echo "Creating worktree with new branch: $branch"
            git worktree add "$worktree_dir" -b "$branch"
          fi

          # Copy .env if it exists
          if [[ -f "$repo_root/.env" ]]; then
            ln -sf "$repo_root/.env" "$worktree_dir/.env"
            echo "Linked .env to worktree"
          fi

          # Run direnv allow in the new worktree
          pushd "$worktree_dir" > /dev/null
          direnv allow
          popd > /dev/null

          # Create new tmux window if inside tmux
          if [[ -n "''${TMUX:-}" ]]; then
            tmux new-window -n "$branch" -c "$worktree_dir"
            echo "Created tmux window: $branch"
          else
            echo ""
            echo "Worktree ready at: $worktree_dir"
            echo "cd $worktree_dir"
          fi
        '')

        (writeShellScriptBin "update-pkgs" ''
          echo "==> Updating all custom packages..."

          pushd ~/nixos/packages > /dev/null

          echo ""; echo "=== claude-code-acp ==="
          ./claude-code-acp/update.sh

          echo ""; echo "=== coderabbit ==="
          ./coderabbit/update.sh

          echo ""; echo "=== dnd5etools ==="
          ./dnd5etools/update.sh

          echo ""; echo "=== gastown ==="
          ./gastown/update.sh

          # echo ""; echo "=== n8n ==="
          # ./n8n/update.sh

          echo ""; echo "=== ntm ==="
          ./ntm/update.sh

          popd > /dev/null

          echo ""
          echo "==> All packages updated!"
          echo "Test builds with: nix build '.#<package>'"
        '')

        # general programs I want to have always available
        imagemagick
        parallel-full
        ffmpeg
        zip
        unzip
        p7zip
        wget
        dig
        killall
        inotify-tools
        lshw
        parted
        nix-du
        exfat
      ];
    };

    services = {
      gnome-keyring.enable = true;
      pass-secret-service.enable = false;
    };

    programs = {
      home-manager.enable = true;
      fastfetch.enable = true;

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      password-store = {
        enable = true;
        package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
      };
    };

    systemd.user.startServices = "sd-switch";
  };
}
