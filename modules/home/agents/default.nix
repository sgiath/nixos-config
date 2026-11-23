{ lib, ... }:
{
  imports = [
    ./antigravity.nix
    ./archive.nix
    ./auto-review.nix
    ./base.nix
    ./claude.nix
    ./cliproxy.nix
    ./codex.nix
    ./cursor.nix
    ./davinci-resolve-mcp.nix
    ./dsh.nix
    ./fx.nix
    ./grok.nix
    ./herdr-server.nix
    ./muse-code.nix
    ./opencode.nix
    ./pi.nix
    ./t3code.nix
  ];

  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
    cliproxyUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cliproxy.sgiath.dev";
      readOnly = true;
      description = ''
        CLIProxyAPI on Vesta (modules/nixos/services/cliproxyapi.nix), used with
        CLIPROXY_API_KEY by Claude Code (to share multiple Claude subscriptions
        and route Mythos) and by non-native proxy clients (OpenCode, Pi, fx).
        Codex, Grok and Antigravity use their native logins directly.
      '';
    };
  };
}
