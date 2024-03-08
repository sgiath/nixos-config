{ config, pkgs, userSettings, ... }:

{
  home.packages = [
    pkgs.delta
  ];

  home.file = {
    ".git/commit-template".text = ''
      type:

      # feat fix docs style refactor perf build test none
    '';
  };

  programs.git = {
    enable = true;

    aliases = {
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

    extraConfig = {
      init = {
        defaultBranch "master";
      };

      user = {
        name = userSettings.username;
        email = userSettings.email;
        signingKey = "0x70F9C7DE34CB3BC8";
      };

      core = {
        editor = "${pkgs.neovim}/bin/nvim";
      };

      commit = {
        gpgSign = true;
        template = "~/.git/commit-template";
      };

      branch = {
        autoSetupRebase = "always";
        sort = "-commiterdate"
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

      tag = {
        gpgSign = true;
      };

      blame = {
        date = "short";
      };

      fetch = {
        prune = true;
      };

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
}
