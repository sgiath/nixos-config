{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.zsh.enable {
    # home.packages = with pkgs; [ ];

    home.sessionVariables = {
      LESS = "-g -i -M -R -S -w -X";
    };

    programs = {
      eza = {
        enable = true;
        git = true;
        icons = "auto";
      };
      bat.enable = true;
      broot = {
        enable = true;
        enableZshIntegration = true;
      };
      btop = {
        enable = true;
        package = pkgs.btop-rocm;
      };
      # command-not-found.enable = true;
      # nix-index.enable = true;
      nix-index-database.comma.enable = true;
      fd.enable = true;
      fzf.enable = true;
      lsd.enable = true;
      mcfly.enable = true;
      zoxide.enable = true;

      zsh = {
        dotDir = "${config.xdg.configHome}/zsh";
        shellAliases = {
          mkdir = "mkdir -p";
          tree = "ls --tree --ignore-glob='node_modules'";
          ls = lib.mkForce "${lib.getExe pkgs.eza} --icons --all --time-style=long-iso";
          ll = lib.mkForce "ls --long --binary --git";
          cat = "${lib.getExe pkgs.bat}";
          du = "${lib.getExe pkgs.dust} -x";
          df = "${lib.getExe pkgs.duf}";
          find = "${lib.getExe pkgs.fd}";
          ping = "${lib.getExe pkgs.gping}";
          ps = "${lib.getExe pkgs.procs}";
          curl = "${lib.getExe pkgs.curlie}";
          man = "${lib.getExe pkgs.tldr}";
          top = "${lib.getExe pkgs.btop-rocm}";
          htop = "${lib.getExe pkgs.btop-rocm}";
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
            autoStartRemote = false;
            defaultSessionName = "Main";
          };
        };
      };
    };
  };
}
