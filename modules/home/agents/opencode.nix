{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 24096;
  # url = "http://127.0.0.1:${toString port}";

  imageModel =
    name: overrides:
    lib.recursiveUpdate {
      inherit name;
      attachment = true;
      reasoning = true;
      tool_call = true;

      limit = {
        context = 1050000;
        input = 1050000;
        output = 128000;
      };

      modalities = {
        input = [
          "text"
          "image"
        ];
        output = [ "text" ];
      };
      options = {
        textVerbosity = "low";
        reasoningSummary = "auto";
      };
      variants = {
        low.reasoningEffort = "low";
        medium.reasoningEffort = "medium";
        high.reasoningEffort = "high";
        xhigh.reasoningEffort = "xhigh";
        auto.reasoningEffort = "auto";
      };
    } overrides;

  # https://opencode.ai/docs/cli/#environment-variables
  # feature flags are read by the server process; exported in `oc` too so the
  # attach-side TUI/plugins see identical settings
  env = {
    OPENCODE_DISABLE_CLAUDE_CODE = "true";
    OPENCODE_ENABLE_EXA = "true";
    OPENCODE_EXPERIMENTAL = "true";
    OPENCODE_EXPERIMENTAL_FILEWATCHER = "true";
    OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
    OPENCODE_EXPERIMENTAL_EXA = "true";
    OPENCODE_EXPERIMENTAL_WORKSPACES = "true";
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
  };

  envFile = pkgs.writeText "opencode-web.env" (
    lib.concatLines (lib.mapAttrsToList (name: value: "${name}=${value}") env)
  );
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      # pkgs.opencode-desktop
      pkgs.llm-agents.opencode2
    ];

    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      package = pkgs.opencode;

      tui = {
        plugin = [ "oh-my-openagent@latest" ];
        scroll_acceleration.enabled = true;
        attention = {
          enabled = true;
          notifications = true;
          sound = true;
        };
      };

      settings = {
        autoupdate = false;
        model = "cli-proxy/gpt-5.6-sol";
        small_model = "cli-proxy/gpt-5.6-luna";
        plugin = [
          "oh-my-openagent@latest"
          "opencode-claude-auth@latest"
          "@plannotator/opencode@latest"
        ];
        provider = {
          cli-proxy = {
            name = "CLIProxyAPI";
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "http://127.0.0.1:8317/v1";
              apiKey = "{env:CLIPROXY_API_KEY}";
            };
            models = {
              "gpt-5.6-sol" = imageModel "GPT 5.6 Sol" { };
              "gpt-5.6-terra" = imageModel "GPT 5.6 Terra" { };
              "gpt-5.6-luna" = imageModel "GPT 5.6 Luna" { };
              "claude-fable-5" = imageModel "Fable 5" {
                limit = {
                  context = 1000000;
                  input = 1000000;
                };
              };
              "claude-opus-5" = imageModel "Opus 5" {
                limit = {
                  context = 1000000;
                  input = 1000000;
                };
              };
              "grok-4.6" = imageModel "Grok 4.6" {
                limit = {
                  context = 500000;
                  input = 500000;
                };
              };
            };
          };
        };
        permission = {
          bash = {
            "*" = "allow";
            "aws *" = "ask";
            "kubectl exec *" = "ask";
          };
          edit = {
            "*" = "allow";
            "/nix/store/**" = "deny";
          };
          external_directory = {
            "~/**" = "allow";
            "/nix/store/**" = "allow";
            "/tmp/**" = "allow";
          };
        };
        lsp = {
          elixir-ls.disabled = true;
          expert = {
            command = [
              "expert"
              "--stdio"
            ];
            extensions = [
              ".ex"
              ".exs"
              ".eex"
              ".heex"
              ".leex"
              ".neex"
            ];
          };
        };
        formatter = {
          mix.disabled = true;
        };
      };
      web = {
        enable = false;
        environmentFile = envFile;
        extraArgs = [
          "--port"
          "${toString port}"
          "--hostname"
          "127.0.0.1"
        ];
      };
    };
    # stylix.targets.opencode.enable = false;

    programs.zsh.shellAliases = {
      oc = lib.getExe pkgs.opencode;
      omo-update = ''
        pushd ~/.cache/opencode && bun update && popd \
        && pushd ~/.cache/opencode/packages/oh-my-openagent@latest && bun add  oh-my-openagent@latest && popd \
        && pushd ~/.config/opencode && bun add @opencode-ai/plugin@latest && popd
      '';
    };
  };
}
