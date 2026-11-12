{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.llama-cpp;
  nebula = config.sgiath.nebula.peers.${config.networking.hostName};
  modelsDir = "/var/lib/llama-cpp-models";
  port = 8081;
in
{
  config = lib.mkIf (config.sgiath.enable && cfg.enable) {
    services.llama-cpp = {
      package = pkgs.llama-cpp-vulkan;
      settings = {
        host = "127.0.0.1";
        inherit port;

        # Router mode: every GGUF in models-dir is listed by /v1/models and
        # loaded on first request; the least recently used one is evicted.
        models-dir = modelsDir;
        models-max = 1;

        ctx-size = 8192;
        parallel = 1;
        gpu-layers = "auto";
        # MiB of VRAM left free when fitting layers; the desktop, ComfyUI and
        # Hex share the GPU.
        fit-target = 2048;
        sleep-idle-seconds = 300;
      };
    };

    # GGUF files are downloaded by hand; the service only reads them. The
    # default ACL keeps new files world-readable despite the user's 077 umask.
    systemd.tmpfiles.rules = [
      "d ${modelsDir} 0755 sgiath users -"
      "A+ ${modelsDir} - - - - default:user::rwx,default:group::r-x,default:other::r-x"
    ];

    systemd.services.llama-cpp.serviceConfig = {
      # Upstream reloads with SIGHUP, which stops the router. Rescan models-dir
      # instead, so `systemctl reload llama-cpp` picks up new GGUF files.
      ExecReload = lib.mkForce "${lib.getExe pkgs.curl} -fsS -o /dev/null http://127.0.0.1:${toString port}/models?reload=1";
      # Mesa's shader cache otherwise tries the unwritable //.cache.
      Environment = [ "XDG_CACHE_HOME=/var/cache/llama-cpp" ];
    };

    # llama-server takes a single --host. The firewall is off, so a wildcard
    # bind would expose it on the LAN and Yggdrasil; instead proxy the Nebula
    # addresses to loopback. FreeBind lets the socket bind before Nebula is up.
    systemd.sockets.llama-cpp-nebula = {
      description = "llama.cpp server on Nebula";
      wantedBy = [ "sockets.target" ];
      listenStreams = [
        "${nebula.ip4}:${toString port}"
        "[${nebula.ip6}]:${toString port}"
      ];
      socketConfig.FreeBind = true;
    };

    systemd.services.llama-cpp-nebula = {
      description = "llama.cpp server on Nebula";
      requires = [ "llama-cpp.service" ];
      after = [ "llama-cpp.service" ];
      serviceConfig = {
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString port}";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };
}
