{ lib, ... }:
{
  imports = [
    ./base.nix
    ./claude.nix
    ./cli-proxy-api.nix
    ./codex.nix
    ./cursor.nix
    ./dsh.nix
    ./omp.nix
    ./openclaw.nix
    ./opencode.nix
    ./pi.nix
    ./system-failure-watcher.nix
    ./t3code.nix
  ];

  options.sgiath.agents.enable = lib.mkEnableOption "LLM agents";
}
