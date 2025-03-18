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
    ./comm.nix
    ./email_client.nix
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

        # general programs I want to have always available
        imagemagick
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
