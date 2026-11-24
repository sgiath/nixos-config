{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.codex = {
      enable = true;
      package = pkgs.llm-agents.codex;
      context = ./AGENTS.md;
    };
  };
}
