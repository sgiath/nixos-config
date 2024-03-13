{ config, nixpkgs, pkgs, ... }:

{
  home.packages = with pkgs; [
    du-dust
    duf
    fd
    gping
    procs
    curlie
    tldr
    zig
  ];

  programs.eza = {
    enable = true;
    git = true;
    icons = true;
  };

  programs.zsh = {
    enable = true;

    shellAliases = {
      mkdir = "mkdir -p";
      tree = "ls --tree --ignore-glob='node_modules'";
      ls = nixpkgs.lib.mkForce "eza --icons --all --time-style=long-iso";
      ll = nixpkgs.lib.mkForce "ls --long --binary --git";
      cat = "bat";
      du = "dust -x";
      df = "duf";
      find = "fd";
      ping = "gping";
      ps = "procs";
      curl = "curlie";
      man = "tldr";
      top = "btop";
      htop = "btop";
    };

    prezto = {
      enable = true;
      pmodules = [
        "environment"
        "terminal"
        "editor"
        "history"
        "directory"
        "tmux"
        "utility"
        "archive"
        "docker"
        "git"
        "gpg"
        "ssh"
        "completion"
        "syntax-highlighting"
        "history-substring-search"
        "autosuggestions"
      ];

	    editor = {
	      dotExpansion = true;
	      promptContext = true;
	    };

      tmux = {
        autoStartLocal = true;
        autoStartRemote = true;
        defaultSessionName = "Main";
      };
    };
  };
}
