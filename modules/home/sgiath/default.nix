{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./audio.nix
    ./bitcoin.nix
    ./chromium.nix
    ./clipboard.nix
    ./comm.nix
    ./email_client.nix
    ./file-explorer.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./vscode.nix
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

          nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-12.331.zip
          nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-Linux-13.342.zip

          case "$1" in
            --ceres)
              nixos-rebuild switch --use-remote-sudo --flake '.#ceres'
              ;;

            --vesta)
              nixos-rebuild switch --use-remote-sudo --flake '.#vesta' --target-host 'sgiath@vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --use-remote-sudo --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --use-remote-sudo --flake .
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
