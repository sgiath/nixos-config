{ lib, ... }:
{
  imports = [
    ./archive.nix
    ./base.nix
    ./claude.nix
    ./cli-proxy-api.nix
    ./codex.nix
    ./cursor.nix
    ./davinci-resolve-mcp.nix
    ./dsh.nix
    ./herdr-server.nix
    ./muse-code.nix
    ./openclaw.nix
    ./opencode.nix
    ./pi.nix
    ./t3code.nix
  ];

  options.sgiath.agents.enable = lib.mkEnableOption "LLM agents";
}
