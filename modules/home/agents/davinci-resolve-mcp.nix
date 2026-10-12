{
  config,
  lib,
  pkgs,
  osConfig,
  namespace,
  ...
}:
let
  cfg = config.services.davinci-resolve-mcp;
  resolve = pkgs.davinci-resolve-studio;
  mcp = pkgs.${namespace}.davinci-resolve-mcp;
  state = "${config.xdg.stateHome}/davinci-resolve-mcp";
  start = pkgs.writeShellScript "start-davinci-resolve-mcp" ''
    set -euo pipefail
    umask 077
    mkdir -p ${lib.escapeShellArg state}
    token=${lib.escapeShellArg "${state}/token"}
    if [[ ! -s $token ]]; then
      ${mcp.python}/bin/python -c 'import secrets; print(secrets.token_urlsafe(32))' > "$token"
    fi
    export DAVINCI_MCP_TOKEN=$(cat "$token")
    # The existing Resolve FHS environment supplies fusionscript's native
    # dependencies and accepts a command instead of launching the GUI.
    exec ${lib.getExe resolve} ${lib.getExe mcp} --transport streamable-http
  '';
in
{
  options.services.davinci-resolve-mcp = {
    enable = lib.mkEnableOption "DaVinci Resolve MCP over authenticated Nebula HTTP";
    host = lib.mkOption {
      type = lib.types.str;
      default = osConfig.sgiath.nebula.peers.${osConfig.networking.hostName}.ip4;
      defaultText = lib.literalExpression "osConfig.sgiath.nebula.peers.\${hostName}.ip4";
      description = "Address to bind; this host's Nebula address by default.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8766;
      description = "Authenticated streamable HTTP MCP port; endpoint is /mcp.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64;
        message = "DaVinci Resolve Studio is only packaged for x86_64-linux.";
      }
    ];
    home.packages = [ mcp ];

    systemd.user.services.davinci-resolve-mcp = {
      Unit = {
        Description = "DaVinci Resolve MCP (authenticated Nebula HTTP)";
        After = [ "network-online.target" ];
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
      Service = {
        ExecStart = "${start}";
        Environment = [
          "DAVINCI_MCP_HOST=${cfg.host}"
          "DAVINCI_MCP_PORT=${toString cfg.port}"
          "DAVINCI_MCP_ALLOWED_HOSTS=${osConfig.networking.hostName}.nebula.sgiath.dev"
          "DAVINCI_RESOLVE_MCP_STATE_DIR=${state}"
          "RESOLVE_MCP_TRACE_FILE=${state}/execution-traces.jsonl"
          "RESOLVE_SCRIPT_API=${resolve.davinci}/Developer/Scripting"
          "RESOLVE_SCRIPT_LIB=${resolve.davinci}/libs/Fusion/fusionscript.so"
          "PYTHONPATH=${resolve.davinci}/Developer/Scripting/Modules"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 30;
        TimeoutStopSec = 15;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
