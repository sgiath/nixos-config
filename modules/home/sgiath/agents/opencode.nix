{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = lib.mkIf (config.sgiath.targets.graphical) [
      pkgs.opencode-desktop
    ];

    xdg.desktopEntries = lib.mkIf (config.sgiath.targets.graphical) {
      opencode-desktop = {
        name = "OpenCode";
        genericName = "OpenCode";
        exec = "opencode-desktop %U";
        icon = "opencode-desktop";
        categories = [ "Development" ];
        mimeType = [ "x-scheme-handler/opencode" ];
      };
    };

    programs.opencode = {
      enable = true;
      package = pkgs.opencode;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      agents = ./agents;
      commands = ./commands;
      skills = ./skills;
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

      web = {
        enable = true;
      };
    };
    stylix.targets.opencode.enable = false;

    # aliases
    programs.zsh.shellAliases = {
      oc = "OPENCODE_EXPERIMENTAL_WORKSPACES=true ${lib.getExe pkgs.opencode}";
    };
  };
}
