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

      git-cliff = {
        enable = true;
        settings = { };
      };

      jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "sgiath";
            email = "sgiath@sgiath.dev";
          };
        };
      };

      git = {
        package = pkgs.gitFull;
        lfs.enable = true;

        maintenance = {
          enable = true;
          repositories = [

          ];
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

        signing = {
          format = "openpgp";
          key = "0x70F9C7DE34CB3BC8";
          signByDefault = true;
        };

        settings = {
          alias = {
            d = "diff";
            aa = "add --all";
            ap = "add --patch";
            cm = "commit --verbose --signoff";
            cn = "commit --verbose --signoff --no-verify";
            ca = "commit --verbose --signoff --all";
            amend = "commit --amend --no-edit";
            ps = "push --progress";
            pl = "pull --autostash --rebase --signoff";
            pf = "push --progress --force-with-lease";
            ss = "status --short";
            ll = "log --all --graph --pretty=format:'%C(magenta)%h %C(white) %an  %ar%C(auto)  %D%n%s%n'";
            tag = "tag --sign";
            main-to-master = "!git symbolic-ref refs/heads/master refs/heads/main && git symbolic-ref refs/remotes/origin/master refs/remotes/origin/main";
          };

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
