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

    [merge]
    squash = true      # Squash commits into one (--no-squash to preserve history)
    commit = true      # Commit uncommitted changes first (--no-commit to skip)
    rebase = true      # Rebase onto target before merge (--no-rebase to skip)
    remove = true      # Remove worktree after merge (--no-remove to keep)
    verify = true      # Run project hooks (--no-verify to skip)

    [[pre-start]]
    copy = "wt step copy-ignored"

    [[pre-start]]
    invalidate-mix-format-cache = "if [ -f .formatter.exs ]; then touch .formatter.exs; fi"

    [[pre-start]]
    direnv = "if [ -f .envrc ]; then direnv allow; fi"

    [step.copy-ignored]
    exclude = [".direnv/", ".devenv/"]
  '';

  programs = {
    worktrunk = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
