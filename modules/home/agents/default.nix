{ lib, ... }:
{
  imports = [
    ./base.nix
    ./claude.nix
    ./cli-proxy-api.nix
    ./codex.nix
    ./cursor.nix
    ./dsh.nix
    ./herdr-server.nix
    ./omp.nix
    ./openclaw.nix
    ./opencode.nix
    ./pi.nix
    ./t3code.nix
  ];

  options.sgiath.agents.enable = lib.mkEnableOption "LLM agents";
}
