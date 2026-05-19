{ pkgs, ... }:
{
  home = {
    packages = [
      pkgs.pi-coding-agent
    ];

    file.".pi/AGENTS.md".source = ./AGENTS.md;
  };
}
