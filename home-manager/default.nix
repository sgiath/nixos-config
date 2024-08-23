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
      imagemagick
      ffmpeg
      zip
      unzip
      wget
      dig
      killall
      inotify-tools
      xfce.thunar
      obsidian
      telegram-desktop

      # privacy
      signal-desktop-beta
      python312Packages.rns
      python312Packages.nomadnet
    ];
  };

  programs = {
    home-manager.enable = true;
    fastfetch.enable = true;
    hexchat.enable = true;
    obs-studio.enable = true;

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    password-store = {
      enable = true;
      package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
    };

    freetube.enable = true;
  };

  services = {
    pass-secret-service.enable = false;
  };
}
