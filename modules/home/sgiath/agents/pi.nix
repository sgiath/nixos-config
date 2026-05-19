{ pkgs, ... }:
{
  home = {
    packages = [
      pkgs.pi-coding-agent
    ];

    file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
  };
}
