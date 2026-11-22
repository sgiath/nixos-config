{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    # `agy`; T3 Code picks it up from PATH as its Antigravity provider.
    programs.antigravity-cli = {
      enable = true;
      package = pkgs.llm-agents.antigravity-cli;
      # ~/.gemini/AGENTS.md and ~/.gemini/antigravity-cli/skills; T3 Code
      # symlinks both into its own Antigravity profile (GEMINI_HOME).
      context.AGENTS = ./AGENTS.md;
      skills = ./skills;
      mcpServers = {
        # Antigravity CLI 1.5.13 does not run MCP OAuth on Streamable HTTP
        # (executor returns 401 Unauthorized on initialize), so bridge it
        # through Nix-pinned mcp-remote; switch to serverUrl once agy handles
        # MCP OAuth natively.
        executor = {
          command = lib.getExe pkgs.llm-agents.mcp-remote;
          args = [
            config.programs.mcp.servers.executor.url
          ];
        };
      };
    };
  };
}
