{ lib, ... }:
{
  imports = [
    ./archive.nix
    ./auto-review.nix
    ./base.nix
    ./claude.nix
    ./codex.nix
    ./cursor.nix
    ./davinci-resolve-mcp.nix
    ./dsh.nix
    ./fx.nix
    ./herdr-server.nix
    ./muse-code.nix
    ./openclaw.nix
    ./opencode.nix
    ./pi.nix
    ./t3code.nix
  ];

  options.sgiath.agents.enable = lib.mkEnableOption "LLM agents";
}
