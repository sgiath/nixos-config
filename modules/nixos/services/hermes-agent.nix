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
      "youtube"
      "web"
    ];
  };
  stateDir = "/home/sgiath/hermes";
  nebula = config.sgiath.nebula;
  host = "niamh.sgiath.dev";
  birdVesta = pkgs.writeShellApplication {
    name = "bird-vesta";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      CREDS_FILE=${lib.escapeShellArg config.sops.secrets.hermes-bird-env.path}
      SCRAPER_DIR=${lib.escapeShellArg "${stateDir}/workspace/twitter-scraper"}
      BIRD_BIN=${lib.getExe pkgs.${namespace}.bird}
    ''
    + builtins.readFile ./hermes-bird-vesta.sh;
  };
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "niamh" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.hermes-agent.enable) {
      users.groups.hermes.members = [ "sgiath" ];

      sops.secrets = {
        hermes-env = {
          sopsFile = ../../../secrets/vesta.yaml;
          owner = "sgiath";
          group = "hermes";
          key = "hermes-env";
          mode = "0400";
          restartUnits = [
            "hermes-agent.service"
            "hermes-dashboard.service"
          ];
        };
        hermes-bird-env = {
          sopsFile = ../../../secrets/vesta.yaml;
          key = "bird-env";
          owner = "sgiath";
          group = "hermes";
          mode = "0400";
          restartUnits = [ "hermes-agent.service" ];
        };
      };

      systemd.services = {
        hermes-agent.after = [ "continuwuity.service" ];
        hermes-dashboard = {
          description = "Hermes Agent web dashboard";
          wantedBy = [ "multi-user.target" ];
          after = [ "hermes-agent.service" ];
          wants = [ "hermes-agent.service" ];

          path = config.services.hermes-agent.extraPackages;
          serviceConfig = {
            User = "sgiath";
            Group = "hermes";
            WorkingDirectory = stateDir;
            EnvironmentFile = [ "${stateDir}/.hermes/.env" ];
            ExecStart = "${hermesPackage}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
            Restart = "on-failure";
            RestartSec = 5;
          };

          environment = {
            HERMES_MANAGED = "false";
            HERMES_DASHBOARD_TUI = "1";
            HERMES_HOME = "${stateDir}/.hermes";
          };
        };
      };

      services = {
        hermes-agent = {
          package = hermesPackage;
          createUser = false;
          user = "sgiath";
          group = "hermes";
          inherit stateDir;
          addToSystemPackages = true;

          extraPackages = with pkgs; [
            imagemagick
            ffmpeg
            # whisper-cpp-vulkan
            yt-dlp
            jq
            pkgs.${namespace}.xurl
            pkgs.${namespace}.bird
            birdVesta
          ];

          environmentFiles = [ config.sops.secrets.hermes-env.path ];
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
              default = "claude-opus-5-5";
              provider = "anthropic";
            };
            fallback_model = {
              model = "gpt-6-sol";
              provider = "openai-codex";
            };

            auxiliary = {
              web_extract = {
                provider = "openai-codex";
                model = "gpt-6-luna";
              };
              title_generation = {
                provider = "openai-codex";
                model = "gpt-6-luna";
              };
              # vision = {};
              # compression = {};
              # skills_hub = {};
              # approval = {};
              # mcp = {};
              # kanban_decomposer = {};
              # profile_describer = {};
              # curator = {};
            };

            timezone = "UTC";

            toolsets = [ "all" ];
            terminal = {
              backend = "local";
              cwd = stateDir;
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
            plugins = {
              hermes-memory-store = {
                auto_extract = true;
                db_path = "${stateDir}/.hermes/memory_store.db";
                default_trust = 0.5;
                hrr_dim = 1024;
              };
            };

            gateway.platforms = {
              api_server = {
                enabled = true;
                extra = {
                  host = "127.0.0.1";
                  port = 8642;
                };
              };
              # Only nginx talks to the webhook listener; the default bind is every interface.
              webhook.extra = {
                host = "127.0.0.1";
                port = 8644;
              };
            };

            agent = {
              max_turns = 150;
              reasoning_effort = "low";
              tool_use_enforcement = "auto";
            };

            approvals.mode = "off";

            delegation = {
              model = "claude-opus-5-5";
              provider = "anthropic";
              max_concurrent_children = 10;
              max_spawn_depth = 2;
            };

            compression = {
              enabled = true;
              codex_gpt55_autoraise = true;
              threshold = 0.5;
              target_ratio = 0.2;
              protect_last_n = 20;
              min_tail_user_messages = 2;
              micro_compact = true;
              threshold_tokens = 100000;
            };

            session_reset = {
              mode = "both";
              idle_minutes = 1440;
              at_hour = 4;
            };

            dashboard = {
              theme = "niamh";
              public_url = "https://${host}";
              basic_auth = {
                username = "sgiath";
                password_hash = "scrypt$16384$8$1$gow0x1oKM9Z1ZfwoIaYXPA==$SevN0dz3ObnQko0fE5XbmsGqEHfS6NZ+K3qsWdLGyQc=";
                session_ttl_seconds = 604800;
              };
            };

            tts = {
              provider = "xai";
              speed = 1.2;

              elevenlabs = {
                model_id = "eleven_multilingual_v2";
                voice_id = "XHqlxleHbYnK8xmft8Vq";
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
                    provider = "anthropic";
                    model = "claude-opus-5-5";
                    reasoning_effort = "high";
                  };

                  reference_models = [
                    {
                      provider = "anthropic";
                      model = "claude-fable-5-1";
                      reasoning_effort = "high";
                    }
                    {
                      provider = "openai-codex";
                      model = "gpt-6-astra";
                      reasoning_effort = "high";
                    }
                    {
                      provider = "xai-oauth";
                      model = "grok-4.7";
                    }
                  ];
                };
              };
            };
          };
        };

        nginx.virtualHosts.${host} = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          # Overlay only; covers /webhooks too, which only ever saw scanners.
          extraConfig = ''
            allow ${nebula.cidr4};
            allow ${nebula.cidr6};
            deny all;
          '';

          locations = {
            "/webhooks".proxyPass = "http://127.0.0.1:8644";

            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:9119";
            };
          };
        };
      };
    })
  ];
}
