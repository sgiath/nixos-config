{
  config,
  lib,
  pkgs,
  ...
}:
let
  gc = (
    pkgs.writeShellScriptBin "gc" ''
      set -euo pipefail

      if [[ $# -lt 1 ]]; then
        echo "Usage: gc <git-url> [project-name]"
        echo ""
        echo "Clones a git repo as bare for worktree workflow"
        exit 1
      fi

      url="$1"

      # Extract project name from URL if not provided
      if [[ $# -ge 2 ]]; then
        project="$2"
      else
        project=$(basename "$url" .git)
      fi

      # Clone as bare repo
      echo "Cloning $url as bare repo..."
      git clone --bare "$url" "$project/.bare"

      cd "$project"

      # Create .git file pointing to bare repo
      echo "gitdir: ./.bare" > .git

      # Configure fetch to get all branches
      git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

      # Fetch all branches
      echo "Fetching all branches..."
      git fetch origin

      # Determine default branch (prefer master, fallback to main)
      if git show-ref --verify --quiet "refs/remotes/origin/master"; then
        default_branch="master"
      elif git show-ref --verify --quiet "refs/remotes/origin/main"; then
        default_branch="main"
      else
        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
      fi

      # Create the main worktree
      echo "Creating worktree for $default_branch..."
      git worktree add "$default_branch" "$default_branch"
    ''
  );

  gw = (
    pkgs.writeShellScriptBin "gw" ''
      set -euo pipefail

      if [[ $# -lt 1 ]]; then
        echo "Usage: gw <branch-name>"
        echo ""
        echo "Creates a git worktree"
        exit 1
      fi

      branch="$1"
      repo_root=$(dirname "$(git rev-parse --git-common-dir)")
      worktree_dir="$repo_root/$branch"

      # Check if branch exists locally or remotely
      if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "Creating worktree for existing local branch: $branch"
        git worktree add "$worktree_dir" "$branch"
      elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        echo "Creating worktree for remote branch: $branch"
        git worktree add "$worktree_dir" "$branch"
      else
        echo "Creating worktree with new branch: $branch"
        git worktree add "$worktree_dir" -b "$branch"
      fi

      # Copy .env if it exists
      if [[ -f "$repo_root/.env" ]]; then
        ln -sf "$repo_root/.env" "$worktree_dir/.env"
        echo "Linked .env to worktree"
      fi

      # Run direnv allow in the new worktree
      pushd "$worktree_dir" > /dev/null
      direnv allow
      popd > /dev/null

      # Create new tmux window if inside tmux
      if [[ -n "''${TMUX:-}" ]]; then
        tmux new-window -n "$branch" -c "$worktree_dir"
        echo "Created tmux window: $branch"
      else
        echo ""
        echo "Worktree ready at: $worktree_dir"
        echo "cd $worktree_dir"
      fi
    ''
  );
in
{
  config = lib.mkIf config.programs.git.enable {
    home = {
      packages = with pkgs; [
        gc
        gw
        git-crypt
      ];

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
          editor = "${pkgs.zed-editor}/bin/zeditor";
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
          ".expert"
          ".elixir-tools"
          ".vscode"
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
