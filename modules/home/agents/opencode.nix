{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 24096;
  # url = "http://127.0.0.1:${toString port}";

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
      pkgs.llm-agents.opencode-desktop
      pkgs.llm-agents.opencode2
    ];

    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      package = pkgs.opencode;

      tui = {
        scroll_acceleration.enabled = true;
        attention = {
          enabled = true;
          notifications = true;
          sound = true;
        };
      };

      settings = {
        autoupdate = false;
        model = "openai-codex/gpt-6-astra";
        small_model = "xai-oauth/grok-4.6";
        plugin = [ "opencode-claude-auth@latest" ];
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
