{ pkgs, userSettings, ... }:

{
  imports = [
    ./gnupg.nix
    ./starship.nix
    ./zsh.nix
    ./tmux.nix
    ./ssh.nix
    ./nvim.nix
    ./git.nix
    ./audio.nix
    ./browser.nix
    ./email_client.nix
    ./games.nix
    ./ollama.nix

    # Wayland
    ./hyprland.nix
    ./kitty.nix
  ];

  home = {
    username = userSettings.username;
    homeDirectory = "/home/${userSettings.username}";

    stateVersion = "23.11";

    packages = [
      (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; })

      (pkgs.writeShellScriptBin "update" ''
        pushd ~/.dotfiles

        git add --all
        git commit --signoff -m "changes"
        git push

        nixos-rebuild switch --use-remote-sudo --flake .
        popd
      '')

      (pkgs.writeShellScriptBin "upgrade" ''
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

      (pkgs.writeShellScriptBin "build-iso" ''
        pushd ~/.dotfiles
        nix run "nixpkgs#nixos-generators" -- --format iso --flake ".#installIso" -o result
        popd
      '')

      # general programs I want to have always available
      pkgs.imagemagick
      pkgs.ffmpeg
      pkgs.zip
      pkgs.unzip
      pkgs.wget
      pkgs.dig
      pkgs.killall
      pkgs.inotify-tools
      pkgs.xfce.thunar
      pkgs.fastfetch
      pkgs.obsidian
      pkgs.telegram-desktop
      pkgs.signal-desktop-beta
    ];
  };

  programs = {
    home-manager.enable = true;
    bat.enable = true;
    btop.enable = true;
    command-not-found.enable = true;

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

  services = {
    pass-secret-service.enable = true;
  };
}
