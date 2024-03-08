{ config, pkgs, userSettings, ... }:

{
  imports = [
    ../user/gnupg.nix
    ../user/starship.nix
    ../user/zsh.nix
    ../user/tmux.nix
    ../user/ssh.nix
    ../user/nvim.nix
    ../user/git.nix
    ../user/stylix.nix
  ];

  home = {
    username = userSettings.username;
    homeDirectory = "/home/${userSettings.username}";

    stateVersion = "23.11"; # Please read the comment before changing.

    packages = [
      (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; })

      (pkgs.writeShellScriptBin "upgrade" ''
        pushd ${userSettings.dotfilesDir}
        git add --all
        git commit
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

    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      sshKeys = [
        "191203A373DD9867A125EC6A9D3EC96416186FEE"
      ];
    };

    ssh-agent.enable = true;

    pass-secret-service.enable = true;

  };

  programs = {
    home-manager.enable = true;

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    bat = {
      enable = true;
    };

    btop = {
      enable = true;
    };

    password-store.enable = true;

    nix-index.enable = true;
    nix-index-database.comma.enable = true;
    command-not-found.enable = true;
  };
}
