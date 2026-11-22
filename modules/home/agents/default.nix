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
        CLIProxyAPI on Vesta (modules/nixos/services/cliproxyapi.nix), which
        every agent tool uses for inference with CLIPROXY_API_KEY. Bare model
        names reach every logged-in account, opencode-go/<model> OpenCode Go.
      '';
    };
  };
}
