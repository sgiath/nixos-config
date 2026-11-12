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

  # Measured on the RX 6950 XT (2026-11-12): each model below fits fully in
  # VRAM at its context. fit=off makes a load fail rather than silently
  # offload layers to the CPU.
  evalProfile = {
    ctx-size = 32768;
    # Only a default: a request's max_tokens overrides it.
    n-predict = 8192;
    n-gpu-layers = 999;
    fit = "off";
    flash-attn = "on";
    cache-type-k = "q8_0";
    cache-type-v = "q8_0";
  };
  noThinking = {
    reasoning = "off";
    reasoning-budget = 0;
  };

  # Sections are keyed by the /v1/models id (the GGUF file name without
  # .gguf); a file without a section gets the [*] defaults. CLI flags would
  # override every section, so per-model settings live only here.
  modelsPreset = pkgs.writeText "llama-cpp-models.ini" (
    lib.generators.toINIWithGlobalSection { mkKeyValue = lib.generators.mkKeyValueDefault { } " = "; } {
      globalSection.version = 1;
      sections = {
        "*" = {
          jinja = true;
          ctx-size = 8192;
          parallel = 1;
          n-gpu-layers = "auto";
          fit = "on";
          # MiB of VRAM left free when fitting layers; the desktop and Hex
          # share the GPU.
          fit-target = 2048;
        };
        "Qwen_Qwen3.5-9B-Q6_K" = evalProfile // noThinking;
        "gemma-4-12b-it-qat-q4_0" = evalProfile // noThinking;
        "Ministral-3-14B-Instruct-2512-Q4_K_M" = evalProfile;
        "Mellum2.1-12B-A2.5B-Thinking-Q4_K_M" = evalProfile;
        "granite-4.2-8b-Q6_K" = evalProfile // noThinking;
        "LFM3-1.7B-Q6_K" = evalProfile // noThinking;
        # 32k leaves too little VRAM headroom next to the desktop.
        "gpt-oss-20b-MXFP4" = evalProfile // {
          ctx-size = 16384;
        };
      };
    }
  );
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
        models-preset = modelsPreset;
        models-max = 1;
        sleep-idle-seconds = 300;
      };
    };

    # GGUF files are downloaded by hand; the service only reads them. The
    # default ACL keeps new files world-readable despite the user's 077 umask.
    systemd.tmpfiles.rules = [
      "d ${modelsDir} 0755 sgiath users -"
      "A+ ${modelsDir} - - - - default:user::rwx,default:group::r-x,default:other::r-x"
      "L+ ${modelsDir}/README.md - - - - ${./llama-cpp/models-README.md}"
    ];

    systemd.services.llama-cpp.serviceConfig = {
      # Upstream reloads with SIGHUP, which stops the router. Rescan models-dir
      # and the preset instead, so `systemctl reload llama-cpp` picks up new
      # GGUF files.
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
