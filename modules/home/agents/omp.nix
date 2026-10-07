{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [ pkgs.llm-agents.omp ];
      sessionVariables = lib.mkIf config.sgiath.roles.desktop.enable {
        PUPPETEER_EXECUTABLE_PATH = lib.getExe config.programs.chromium.package;
      };
      # OMP has no Home Manager module; feed it the shared `programs.mcp` servers
      # the same way the Claude Code module does.
      file.".omp/agent/mcp.json".text = builtins.toJSON {
        mcpServers = lib.mapAttrs (
          name: server:
          lib.hm.mcp.transformMcpServer {
            inherit server;
            extraTransforms = [
              lib.hm.mcp.addType
              (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; })
            ];
          }
        ) config.programs.mcp.servers;
      };
    };
  };
}
