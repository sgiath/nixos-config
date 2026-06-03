{ pkgs, ... }:
{
  home = {
    packages = [
      pkgs.llm-agents.pi
    ];

    file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  };
}
