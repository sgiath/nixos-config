{ config, pkgs, ... }:

{
  imports = [
    ./xmonad/xmonad.nix
    ./polybar.nix
    ./gnupg.nix
    ./starship.nix
    ./wezterm.nix
    ./zsh.nix
    ./tmux.nix
  ];

  home = {
    username = "sgiath";
    homeDirectory = "/home/sgiath";

    stateVersion = "23.11"; # Please read the comment before changing.

    packages = [
    (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; })

    (pkgs.writeShellScriptBin "upgrade" ''
      pushd "/home/sgiath/.dotfiles"
      nix flake update
      sudo nixos-rebuild switch --flake .
      home-manager switch --flake .
      popd
    '')
    ];

    file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    };

    sessionVariables = { };
  };

  services = {

    easyeffects = {
      enable = true;
    };

    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      sshKeys = [
        "191203A373DD9867A125EC6A9D3EC96416186FEE"
      ];
    };

    ssh-agent.enable = true;

  };

  programs = {
    home-manager.enable = true;

    # neovim = {
    #   enable = true;
    #   defaultEditor = true;
    # };

    NvChad = {
      enable = true;
      defaultEditor = true;
      otherConfigs = ./NvChad;
    };

    git = {
      enable = true;
      userName = "sgiath";
      userEmail = "sgiath@sgiath.dev";
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
