{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./audio.nix
    ./chromium.nix
    ./davinci.nix
    ./email_client.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./waybar.nix
    ./zsh.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    home = {
      username = "sgiath";
      homeDirectory = "/home/sgiath";

      stateVersion = "23.11";

      packages = with pkgs; [
        (nerdfonts.override { fonts = [ "RobotoMono" ]; })

        (writeShellScriptBin "update" ''
          pushd ~/.dotfiles

          git add --all
          git commit --signoff -m "changes"
          git push

          nixos-rebuild switch --use-remote-sudo --flake .
          popd
        '')

        (writeShellScriptBin "upgrade" ''
          pushd ~/.dotfiles

          git add --all
          git commit --signoff -m "changes"

          nix flake update
          git add --all
          git commit --signoff -m "flake update"
          git push

          nixos-rebuild switch --use-remote-sudo --flake .
          popd
        '')

        (writeShellScriptBin "build-iso" ''
          pushd ~/.dotfiles
          nix run "nixpkgs#nixos-generators" -- --format iso --flake ".#installIso" -o result
          popd
        '')

        # general programs I want to have always available
        appimage-run
        imagemagick
        ffmpeg
        zip
        unzip
        wget
        dig
        killall
        inotify-tools
        lshw

        python312Packages.rns
        python312Packages.nomadnet
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
