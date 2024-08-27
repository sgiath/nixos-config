{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.zsh.enable {
    programs = {
      eza = {
        enable = true;
        git = true;
        icons = true;
      };
      bat.enable = true;
      broot = {
        enable = true;
        enableZshIntegration = true;
      };
      btop.enable = true;
      command-not-found.enable = true;
      fd.enable = true;
      fzf.enable = true;
      lsd.enable = true;
      mcfly.enable = true;

      zsh = {
        shellAliases = {
          mkdir = "mkdir -p";
          tree = "ls --tree --ignore-glob='node_modules'";
          ls = lib.mkForce "${pkgs.eza}/bin/eza --icons --all --time-style=long-iso";
          ll = lib.mkForce "ls --long --binary --git";
          cat = "${pkgs.bat}/bin/bat";
          du = "${pkgs.du-dust}/bin/dust -x";
          df = "${pkgs.duf}/bin/duf";
          find = "${pkgs.fd}/bin/fd";
          ping = "${pkgs.gping}/bin/gping";
          ps = "${pkgs.procs}/bin/procs";
          curl = "${pkgs.curlie}/bin/curlie";
          man = "${pkgs.tldr}/bin/tldr";
          top = "${pkgs.btop}/bin/btop";
          htop = "${pkgs.btop}/bin/btop";
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
            # "gpg"
            # "ssh"
            "completion"
            "syntax-highlighting"
            "history-substring-search"
            "autosuggestions"
          ];

          editor = {
            dotExpansion = true;
            promptContext = true;
          };

          tmux = lib.mkIf config.programs.tmux.enable {
            autoStartLocal = true;
            autoStartRemote = true;
            defaultSessionName = "Main";
          };
        };
      };
    };
  };
}
