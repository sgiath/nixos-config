{ pkgs, userSettings, ... }:

{
  imports = [
    ../user/gnupg.nix
    ../user/starship.nix
    ../user/zsh.nix
    ../user/tmux.nix
    ../user/ssh.nix
    ../user/nvim.nix
    ../user/git.nix
  ];

  home = {
    username = userSettings.username;
    homeDirectory = "/home/${userSettings.username}";

    stateVersion = "23.11";

    packages = [
      (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; })

      (pkgs.writeShellScriptBin "update" ''
        pushd ~/.dotfiles
        doas nixos-rebuild switch --flake .
        popd
      '')

      (pkgs.writeShellScriptBin "upgrade" ''
        pushd ~/.dotfiles
        nix flake update
        doas nixos-rebuild switch --flake .
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
      package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
    };
  };
}
