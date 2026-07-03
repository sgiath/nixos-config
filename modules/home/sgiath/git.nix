{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  worktrunk = inputs.worktrunk.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf config.programs.git.enable {
    home = {
      packages = with pkgs; [
        git-crypt
        worktrunk
      ];
    };

    xdg.configFile = {
      "git/commit-template".text = ''
        type:

        # feat fix docs style refactor perf build test none
      '';
    };

    programs = {
      zsh.initContent = lib.mkOrder 1000 ''
        eval "$(${lib.getExe worktrunk} config shell init zsh)"
      '';

      gh = {
        enable = true;
        settings = {
          editor = "${lib.getExe pkgs.zed-editor}";
          git_protocol = "ssh";
        };
      };

      git-cliff = {
        enable = true;
        settings = { };
      };

      git = {
        package = pkgs.gitFull;
        lfs.enable = true;

        maintenance = {
          enable = true;
          repositories = [ ];
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
          ".expert"
          ".elixir-tools"
        ];

        signing = {
          format = "openpgp";
          signByDefault = true;
        };

        includes = [
          {
            condition = "gitdir:~/develop/crazyegg/";
            # path = "${config.xdg.configHome}/git/config.crazyegg";
            contents = {
              user = "Filip Vavera";
              email = "filip@crazyegg.com";
            };
          }
          {
            condition = "gitdir:~/develop/remote/";
            # path = "${config.xdg.configHome}/git/config.remote";
            contents = {
              user = "Filip Vavera";
              email = "filip.vavera@remote.com";
              signingKey = "0x72494C2C6428E2A2";
            };
          }
        ];

        settings = {
          alias = {
            d = "diff";
            aa = "add --all";
            ap = "add --patch";
            cm = "commit --verbose";
            cn = "commit --verbose --no-verify";
            ca = "commit --verbose --all";
            amend = "commit --amend --no-edit";
            ps = "push --progress";
            pl = "pull --autostash --rebase";
            pf = "push --progress --force-with-lease";
            ss = "status";
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
            editor = "${lib.getExe pkgs.neovim}";
          };

          advice = {
            addEmptyPathspec = false;
            pushNonFastForward = false;
            statusHints = true;
          };

          commit = {
            gpgSign = true;
            template = "${config.xdg.configHome}/git/commit-template";
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
