{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.open-webui.enable) {
    services = {
      nginx.virtualHosts."open-webui.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8082";
        };
      };

      open-webui = {
        port = 8082;
        package = pkgs.open-webui;
        # package = pkgs.${namespace}.open-webui;
        environment = {
          # default
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";

          # general
          ENV = "prod";
          WEBUI_URL = "https://open-webui.sgiath.dev";
          WEBHOOK_URL = "https://open-webui.sgiath.dev";
          WHISPER_MODEL_AUTO_UPDATE = "True";

          OLLAMA_BASE_URL = "http://192.168.1.6:11434";

          # RAG
          ENABLE_RAG_WEB_SEARCH = "True";
          RAG_WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "https://search.sgiath.dev/search?q=<query>";
        };
      };
    };
  };
}
