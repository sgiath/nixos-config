{ pkgs, userSettings, ... }:

{
  home.file = {
    ".git/commit-template".text = ''
      type:

      # feat fix docs style refactor perf build test none
    '';
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    delta = {
      enable = false;
    };

    aliases = {
      d = "diff";
      aa = "add --all";
      cm = "commit --signoff";
      ps = "push --progress";
      pl = "pull --autostash --rebase --signoff";
      pf = "push --progress --force-with-lease";
      ss = "status";
      tag = "tag --sign";
      amend = "commit --amend --no-edit";
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
      ".elixir_ls"
      "result"
    ];

    extraConfig = {
      init.defaultBranch = "master";
      safe.directory = "/home/${userSettings.username}/.dotfiles/";

      user = {
        name = userSettings.username;
        email = userSettings.email;
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

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "${pkgs.neovim}/bin/nvim";
    };
  };
}
