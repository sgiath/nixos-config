{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  hermesPackage = pkgs.hermes-agent.override {
    extraDependencyGroups = [
      "matrix"
      "voice"
      "anthropic"
      "firecrawl"
      "cli"
      "youtube"
      "web"
    ];
  };
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.hermes-agent.enable) {
    users.groups.hermes.members = [ "sgiath" ];

    systemd.services = {
      hermes-agent.after = [ "continuwuity.service" ];
      hermes-dashboard = {
        description = "Hermes Agent web dashboard";
        wantedBy = [ "multi-user.target" ];
        after = [ "hermes-agent.service" ];
        wants = [ "hermes-agent.service" ];

        serviceConfig = {
          User = "sgiath";
          Group = "hermes";
          WorkingDirectory = "/home/sgiath/hermes";
          EnvironmentFile = [ "/home/sgiath/hermes/.hermes/.env" ];
          ExecStart = "${hermesPackage}/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open";
          Restart = "on-failure";
          RestartSec = 5;
        };

        environment = {
          HERMES_MANAGED = "true";
          HERMES_DASHBOARD_TUI = "1";
        };
      };
    };

    services = {
      hermes-agent = {
        package = hermesPackage;
        createUser = false;
        user = "sgiath";
        group = "hermes";
        stateDir = "/home/sgiath/hermes";
        addToSystemPackages = true;

        extraPackages = with pkgs; [
          imagemagick
          ffmpeg
          # whisper-cpp-vulkan
          yt-dlp
          jq
          pkgs.${namespace}.xurl
          pkgs.${namespace}.bird
        ];

        environmentFiles = [ "/data/hermes_env" ];
        environment = {
          HERMES_DASHBOARD_TUI = "1";

          MATRIX_HOMESERVER = "https://matrix.sgiath.dev";
          MATRIX_USER_ID = "@niamh:sgiath.dev";
          MATRIX_ALLOWED_USERS = "@sgiath:sgiath.dev";
          MATRIX_HOME_CHANNEL = "!exHpssN2dwpo9ufw23:sgiath.dev";
          MATRIX_HOME_ROOM = "!exHpssN2dwpo9ufw23:sgiath.dev";
          MATRIX_ENCRYPTION = "false";

          WEBHOOK_ENABLED = "true";
          OBSIDIAN_VAULT_PATH = "~/notes";
          SEARXNG_URL = "https://search.sgiath.dev";
        };

        settings = {
          model = {
            default = "claude-fable-5";
            provider = "anthropic";
          };
          fallback_model = {
            model = "gpt-5.6-sol";
            provider = "openai-codex";
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
            skin = "mono";
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
            model = "gpt-5.6-luna";
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

          web = {
            search_backend = "searxng";
            extract_backend = "firecrawl";
          };

          dashboard = {
            theme = "mono";
            public_url = "https://niamh.sgiath.dev";
            basic_auth = {
              username = "sgiath";
              password_hash = "scrypt$16384$8$1$gow0x1oKM9Z1ZfwoIaYXPA==$SevN0dz3ObnQko0fE5XbmsGqEHfS6NZ+K3qsWdLGyQc=";
              session_ttl_seconds = 604800;
            };
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

          x_search.model = "grok-4.5";

          moa = {
            default_preset = "default";
            presets = {
              default = {
                enabled = true;

                aggregator = {
                  provider = "openai-codex";
                  model = "gpt-5.6-sol";
                  reasoning_effort = "high";
                };

                reference_models = [
                  {
                    provider = "anthropic";
                    model = "claude-fable-5";
                    reasoning_effort = "high";
                  }
                  {
                    provider = "openai-codex";
                    model = "gpt-5.6-sol";
                    reasoning_effort = "high";
                  }
                  {
                    provider = "xai-oauth";
                    model = "grok-4.5";
                  }
                ];
              };
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
              proxyPass = "http://127.0.0.1:9119";
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
