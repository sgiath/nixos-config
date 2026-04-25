{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.sgiath.server.enable && config.services.hermes-agent.enable) {
    users.groups.hermes.members = [ "sgiath" ];
    systemd.services.hermes-agent.after = [ "continuwuity.service" ];
    services = {
      hermes-agent = {
        createUser = false;
        user = "sgiath";
        group = "hermes";
        stateDir = "/home/sgiath/hermes";
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
          MATRIX_HOME_CHANNEL = "!exHpssN2dwpo9ufw23:sgiath.dev";
          MATRIX_ENCRYPTION = "false";

          WEBHOOK_ENABLED = "true";

          OBSIDIAN_VAULT_PATH = "~/notes";
        };

        settings = {
          model = {
            default = "gpt-5.5";
            provider = "openai-codex";
          };
          fallback_model = {
            provider = "openrouter";
            model = "z-ai/glm-5-turbo";
          };

          timezone = "UTC";

          toolsets = [ "all" ];
          terminal = {
            backend = "local";
            cwd = "/home/sgiath/hermes";
            timeout = 180;
          };

          matrix = {
            require_mention = false;
            free_response_rooms = [
              "!exHpssN2dwpo9ufw23:sgiath.dev"
              "!UJC9AZ04bM93iIVfzf:sgiath.dev"
              "!8XctJQ9bxcnbl2wwB8:sgiath.dev"
              "!snfKPYkaPfv7JU3Qux:sgiath.dev"
              "!10Sk6sJuFifga0t3wX:sgiath.dev"
            ];
          };

          display = {
            personality = "kawaii";
            skin = "charizard";
          };

          memory = {
            provider = "holographic";
            memory_enabled = true;
            user_profile_enabled = true;
          };
          plugins.hermes-memory-store = {
            auto_extract = true;
            db_path = "/home/sgiath/hermes/.hermes/memory_store.db";
            default_trust = 0.5;
            hrr_dim = 1024;
          };

          agent = {
            max_turns = 150;
            reasoning_effort = "low";
            tool_use_enforcement = "auto";
          };

          approvals.mode = "off";

          delegation = {
            model = "gpt-5.4-mini";
            provider = "openai-codex";
            max_concurrent_children = 10;
            max_spawn_depth = 2;
          };

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
            provider = "xai";
            elevenlabs = {
              model_id = "eleven_multilingual_v2";
              voice_id = "XHqlxleHbYnK8xmft8Vq";
            };
            openai = {
              model = "gpt-4o-mini-tts";
              voice = "maple";
            };
            xai = {
              voice_id = "ara";
              language = "en";
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
