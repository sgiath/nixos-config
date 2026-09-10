{ lib, ... }:
{
  disabledModules = [ "programs/worktrunk.nix" ];

  xdg.configFile."worktrunk/config.toml".text = ''
    skip-shell-integration-prompt = true

    [list]
    summary = true    # Enable LLM branch summaries (requires [commit.generation])

    full = false       # Show CI, main…± diffstat, and LLM summaries (--full)
    branches = false   # Include branches without worktrees (--branches)
    remotes = false    # Include remote-only branches (--remotes)
    json-schema = 2

    [commit]
    stage = "all"

    [commit.generation]
    command = "pi --model opencode-go/glm-5.3-flash:high --tools read,grep,find,ls"

    [merge]
    squash = true      # Squash commits into one (--no-squash to preserve history)
    commit = true      # Commit uncommitted changes first (--no-commit to skip)
    rebase = true      # Rebase onto target before merge (--no-rebase to skip)
    remove = true      # Remove worktree after merge (--no-remove to keep)
    verify = true      # Run project hooks (--no-verify to skip)

    [post-switch]
    herdr = 'if [ "$HERDR_ENV" = 1 ]; then herdr worktree open --workspace "$HERDR_WORKSPACE_ID" --path {{ worktree_path }} --label {{ branch }} --focus; fi'

    [[pre-start]]
    copy = "wt step copy-ignored"

    [[pre-start]]
    invalidate-mix-format-cache = "if [ -f .formatter.exs ]; then touch .formatter.exs; fi"

    [[pre-start]]
    direnv = "direnv allow"

    [[pre-remove]]
    preserve-omo-plans = "if [ -d .omo/plans ]; then mkdir -p {{ primary_worktree_path }}/.omo/plans && cp -a .omo/plans/. {{ primary_worktree_path }}/.omo/plans/; fi"

    [step.copy-ignored]
    exclude = [".direnv/", ".devenv/"]
  '';

  programs = {
    worktrunk = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh.initContent = lib.mkAfter ''
      # In Herdr, wt switch opens and focuses the destination worktree workspace.
      functions[_worktrunk_wt]=$functions[wt]
      wt() {
        if [[ "''${HERDR_ENV:-}" == 1 && "$1" == switch ]]; then
          _worktrunk_wt switch --no-cd "''${@:2}"
        else
          _worktrunk_wt "$@"
        fi
      }
    '';
  };
}
