{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.git.enable {
    home = {
      packages = with pkgs; [ git-crypt jujutsu ];

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
        diff-so-fancy.enable = true;

        aliases = {
          d = "diff";
          aa = "add --all";
          ap = "add --patch";
          cm = "commit --signoff --no-verify --verbose";
          ca = "commit --all --signoff --no-verify --verbose";
          ps = "push --progress";
          pl = "pull --autostash --rebase --signoff";
          pf = "push --progress --force-with-lease";
          ss = "status --short";
          ll = "log --all --graph --pretty=format:'%C(magenta)%h %C(white) %an  %ar%C(auto)  %D%n%s%n'";
          tag = "tag --sign";
          amend = "commit --amend --no-edit --no-verify";
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
          ".opencode"
        ];

        extraConfig = {
          init.defaultBranch = "master";
          safe.directory = "${config.home.homeDirectory}/nixos/";

          user = {
            name = "sgiath";
            email = "sgiath@sgiath.dev";
            signingKey = "0x70F9C7DE34CB3BC8";
          };

          core = {
            compression = 9;
            whitespace = "error";
            preloadindex = true;
            editor = "${pkgs.neovim}/bin/nvim";
          };

          advice = {
            addEmptyPathspec = false;
            pushNonFastForward = false;
            statusHints = false;
          };

          commit = {
            gpgSign = true;
            template = "~/.git/commit-template";
          };

          diff = {
            context = 5;
            interHunkContext = 10;
            renames = "copies";
          };

          branch = {
            autoSetupRebase = "always";
            sort = "-committerdate";
          };

          pull = {
            default = "current";
            rebase = true;
            gpgSign = true;
          };

          push = {
            autoSetupRemote = true;
            followTags = true;
            default = "current";
            gpgSign = "if-asked";
          };

          rebase = {
            autoStash = true;
            missingCommitsCheck = true;
          };

          status = {
            branch = true;
            showStash = true;
            showUntrackedFiles = "all";
          };

          log = {
            abbrevCommit = true;
          };

          tag = {
            sort = "-taggerdate";
            gpgSign = true;
          };

          blame.date = "short";
          fetch.prune = true;

          color = {
            branch = "auto";
            diff = "auto";
            decorate = "auto";
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

          pager = {
            branch = false;
            tag = false;
          };

          interactive = {
            singlekey = true;
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
