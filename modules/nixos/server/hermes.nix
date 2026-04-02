{
  inputs,
  system,
  config,
  lib,
  pkgs,
  ...
}:

let
  hermesPackage = inputs.hermes-agent.packages.${system}.default;
  # nixpkgs' python311Packages.matrix-nio currently fails to evaluate in this
  # channel because one of its test-only dependency chains pulls sphinx 9.
  hermesMatrixNio = pkgs.python311Packages.buildPythonPackage rec {
    pname = "matrix-nio";
    version = "0.25.2";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "poljar";
      repo = "matrix-nio";
      tag = version;
      hash = "sha256-ZNYK5D4aDKE+N62A/hPmTphir+UsWvj3BW2EPG1z+R4=";
    };

    postPatch = ''
      substituteInPlace src/nio/client/async_client.py \
        --replace-fail "from aiohttp_socks import ProxyConnector" $'try:\n    from aiohttp_socks import ProxyConnector\nexcept ImportError:\n    ProxyConnector = None'

      substituteInPlace src/nio/client/async_client.py \
        --replace-fail "connector = ProxyConnector.from_url(self.proxy) if self.proxy else None" \
        "connector = ProxyConnector.from_url(self.proxy) if self.proxy and ProxyConnector is not None else None"
    '';

    build-system = [ pkgs.python311Packages.setuptools ];

    # Hermes already ships aiofiles/aiohttp/h11/h2/jsonschema in its venv.
    dependencies = with pkgs.python311Packages; [
      pycryptodome
      unpaddedbase64
    ];

    doCheck = false;
    dontCheckRuntimeDeps = true;
  };
  hermesMatrixPackage = pkgs.symlinkJoin {
    name = "hermes-agent-with-matrix";
    paths = [ hermesPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      matrixPythonPath="${pkgs.python311Packages.makePythonPath [ hermesMatrixNio ]}"

      for bin in "$out/bin/hermes" "$out/bin/hermes-agent" "$out/bin/hermes-acp"; do
        wrapProgram "$bin" --prefix PYTHONPATH : "$matrixPythonPath"
      done
    '';
  };
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.hermes-agent.enable) {
    services = {
      hermes-agent = {
        package = hermesMatrixPackage;
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
        };

        settings = {
          model = {
            default = "claude-opus-4-6";
            provider = "anthropic";
          };

          fallback_model = {
            provider = "openrouter";
            model = "minimax/minimax-m2.7";
          };

          display = {
            personality = "catgirl";
            skin = "charizard";
          };

          toolsets = [ "all" ];

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
