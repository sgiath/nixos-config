{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.git.enable {
    home = {
      packages = with pkgs; [ git-crypt ];

      file = {
        ".git/commit-template".text = ''
          type:

          # feat fix docs style refactor perf build test none
        '';
      };
    };

    programs = {
      gh = {
        enable = true;
        settings = {
          editor = "nvim";
          git_protocol = "ssh";
        };
      };
      git = {
        lfs.enable = true;
        delta.enable = true;

        aliases = {
          d = "diff";
          aa = "add --all";
          cm = "commit --signoff --no-verify";
          ca = "commit --all --signoff --no-verify";
          ps = "push --progress";
          pl = "pull --autostash --rebase --signoff";
          pf = "push --progress --force-with-lease";
          ss = "status";
          tag = "tag --sign";
          amend = "commit --amend --no-edit";
          main-to-master = "!git symbolic-ref refs/heads/master refs/heads/main && git symbolic-ref refs/remotes/origin/master refs/remotes/origin/main";
        };

        attributes = [
          "* text=auto"

          # Images
          "*.ico binary"
          "*.png binary"
          "*.jpg binary"
        ];

        ignores = [
          ".direnv"
          ".devenv"
          ".elixir_ls"
          ".zig-cache"
          "result"
        ];

        extraConfig = {
          init.defaultBranch = "master";
          safe.directory = "${config.home.homeDirectory}/.dotfiles/";

          user = {
            name = "sgiath";
            email = "sgiath@sgiath.dev";
            signingKey = "0x70F9C7DE34CB3BC8";
          };

          core.editor = "${pkgs.neovim}/bin/nvim";

          commit = {
            gpgSign = true;
            template = "~/.git/commit-template";
          };

          branch = {
            autoSetupRebase = "always";
          };

          pull = {
            gpgSign = true;
            rebase = true;
          };

          push = {
            default = "current";
            gpgSign = "if-asked";
          };

          status = {
            branch = true;
            showUntrackedFiles = "all";
          };

          tag.gpgSign = true;
          blame.date = "short";
          fetch.prune = true;

          color = {
            branch = "auto";
            diff = "auto";
            interactive = "auto";
            status = "auto";
            ui = "always";
          };

          maintenance = {
            strategy = "incremental";

            "*" = {
              enable = true;
              schedule = "hourly";
              auto = -1;
            };
          };

          rerere = {
            enabled = true;
            autoUpdate = true;
          };
        };
      };
    };
  };
}
