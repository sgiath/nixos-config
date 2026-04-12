{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf (config.sgiath.server.enable && config.services.hermes-agent.enable) {
    services = {
      hermes-agent = {
        addToSystemPackages = true;

        extraPackages = with pkgs; [
          imagemagick
          ffmpeg
          whisper-cpp-vulkan
          yt-dlp
          jq
        ];

        environmentFiles = [ "/data/hermes_env" ];
        environment = {
          MATRIX_HOMESERVER = "https://matrix.sgiath.dev";
          MATRIX_USER_ID = "@niamh:sgiath.dev";
          MATRIX_ALLOWED_USERS = "@sgiath:sgiath.dev";
          MATRIX_HOME_ROOM = "!UJC9AZ04bM93iIVfzf:sgiath.dev";
          MATRIX_ENCRYPTION = "false";

          WEBHOOK_ENABLED = "true";

          HERMES_OPTIONAL_SKILLS = "${inputs.hermes-agent}/optional-skills";
        };

        settings = {
          model = {
            default = "gpt-5.4";
            provider = "openai-codex";
          };
          toolsets = [ "all" ];
          terminal = {
            backend = "local";
            cwd = ".";
            timeout = 180;
          };

          fallback_model = {
            provider = "openrouter";
            model = "minimax/minimax-m2.7";
          };

          display = {
            personality = "catgirl";
            skin = "charizard";
          };
          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };

          agent.max_turns = 150;
          approvals.mode = "off";

          compression = {
            enabled = true;
            threshold = 0.5;
            target_ratio = 0.2;
            protect_last_n = 20;
            summary_model = "";
            summary_provider = "auto";
            summary_base_url = null;
          };

          session_reset = {
            mode = "both";
            idle_minutes = 1440;
            at_hour = 4;
          };

          tts = {
            provider = "openai";
            openai = {
              model = "gpt-4o-mini-tts";
              voice = "maple";
            };
          };

          stt = {
            enabled = true;
            provider = "local";
            local = {
              model = "ggml-large-v3-turbo";
            };
          };
        };
      };

      nginx.virtualHosts = {
        "niamh.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          locations = {
            "/webhooks" = {
              proxyPass = "http://127.0.0.1:8644";
            };

            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:8644";
              extraConfig = ''
                allow 127.0.0.1;
                allow ::1;
                deny 192.168.1.1;
                allow 192.168.1.0/24;
                deny all;
              '';
            };
          };
        };
      };
    };
  };
}
