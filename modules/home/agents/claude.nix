{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = with pkgs.llm-agents; [ claude-desktop ];
      file.".claude-remote/CLAUDE.md".source = ./AGENTS.md;
      file.".claude-remote/skills" = {
        source = ./skills;
        recursive = true;
      };
    };

    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      package = pkgs.llm-agents.claude-code;
      context = ./AGENTS.md;
      skills = ./skills;
    };

    # Claude rewrites settings.json itself (theme, plugins), so merge the
    # attribution policy into both config dirs instead of owning the file.
    home.activation.claudeAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for f in "$HOME/.claude/settings.json" "$HOME/.claude-remote/settings.json"; do
        old=$(cat "$f" 2>/dev/null || true)
        new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} '.attribution = {commit: "", pr: ""}')
        if [ "$new" != "$old" ]; then
          run mkdir -p "$(dirname "$f")"
          run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
        fi
      done
    '';

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.llm-agents.claude-code} --dangerously-skip-permissions";
    };
  };
}
