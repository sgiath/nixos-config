{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Without a usable default Pi silently picks the first natively logged-in
  # provider, so it refuses to start without the proxy key (cliproxy.nix).
  pi = pkgs.symlinkJoin {
    name = "pi-cliproxy";
    paths = [
      (pkgs.writeShellScriptBin "pi" ''
        if [ -z "''${CLIPROXY_API_KEY:-}" ]; then
          echo "pi: CLIPROXY_API_KEY is not set; refusing to fall back to a native login" >&2
          exit 1
        fi
        exec ${pkgs.llm-agents.pi}/bin/pi "$@"
      '')
      pkgs.llm-agents.pi
    ];
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ pi ];
  };
}
