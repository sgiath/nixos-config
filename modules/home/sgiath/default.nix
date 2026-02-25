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
    ./openclaw.nix
    ./opencode.nix
    ./ssh.nix
    ./starship.nix
    ./stylix.nix
    ./tmux.nix
    ./voxtype.nix
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

        (writeShellScriptBin "update-pkgs" ''
          echo "==> Updating all custom packages..."

          pushd ~/nixos/packages > /dev/null

          echo ""; echo "=== claude-code-acp ==="
          ./claude-code-acp/update.sh

          echo ""; echo "=== dnd5etools ==="
          ./dnd5etools/update.sh

          echo ""; echo "=== gogcli ==="
          ./gogcli/update.sh

          # echo ""; echo "=== n8n ==="
          # ./n8n/update.sh

          echo ""; echo "=== openclaw ==="
          ./openclaw/update.sh

          echo ""; echo "=== openwork ==="
          ./openwork/update.sh

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
