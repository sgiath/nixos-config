{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.opencode = {
      enable = true;
      package = pkgs.llm-agents.opencode2;
      context = ./AGENTS.md;
      settings = {
        update = "disable";
        share = "disabled";
        plugins = [
          "-opencode.provider.openai"
          "-opencode.provider.chatgpt"
        ];
        # Keep only OpenCode Go enabled so saved native logins and GITHUB_TOKEN
        # never surface other providers; the OpenCode Go login stays manual.
        policies = [
          {
            action = "provider.use";
            resource = "*";
            effect = "deny";
          }
          {
            action = "provider.use";
            resource = "opencode-go";
            effect = "allow";
          }
        ];
        # OpenCode 2 nests MCP servers under mcp.servers (unlike HM's
        # enableMcpIntegration, which emits OpenCode 1's flat mcp.<name>).
        mcp.servers.executor = {
          type = "remote";
          url = config.programs.mcp.servers.executor.url;
        };
      };
    };

    home.packages = [ pkgs.llm-agents.opencode2-desktop ];

    # Stylix's opencode target still writes OpenCode 1's tui.json, which OpenCode 2 ignores.
    stylix.targets.opencode.enable = false;
  };
}
