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
      package = pkgs.llm-agents.opencode;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      settings = {
        autoupdate = false;
        permission = {
          bash = {
            "*" = "allow";
            "aws *" = "ask";
            "kubectl exec *" = "ask";
          };
          read = {
            "/nix/store/**" = "allow";
          };
          edit = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
          external_directory = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
        };
        plugin = [
          "@plannotator/opencode@latest"
        ];
        server = {
          hostname = "0.0.0.0";
          mdns = true;
          cors = [
            "http://localhost:4096"
            "http://192.168.1.7:4096"
            "http://localhost:4097"
            "http://192.168.1.7:4097"
          ];
        };
        experimental = {
          batch_tool = true;
        };
      };

      web.enable = true;
    };
    stylix.targets.opencode.enable = false;

    programs.zsh.shellAliases = {
      oc = "OPENCODE_EXPERIMENTAL_WORKSPACES=true ${lib.getExe pkgs.llm-agents.opencode}";
    };
  };
}
