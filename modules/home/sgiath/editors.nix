{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.vscode.enable {
    # VSCode
    programs.vscode = {
      # package = pkgs.vscodium;
      profiles.default.userSettings = {
        "security.workspace.trust.untrustedFiles" = "open";
        "editor.tabSize" = 2;
        "editor.minimap.enabled" = false;
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;
        "editor.wordWrapColumn" = 98;
        # Github Copilot
        "github.copilot.enable"."*" = true;
        # makefile plugin
        "makefile.configureOnOpen" = true;
        # shellcheck plugin
        "shellcheck.customArgs" = [ "-x" ];
      };
    };
    stylix.targets.vscode.enable = false;

    # Zed editor
    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;
      # package = inputs.zed-editor.packages.${pkgs.stdenv.hostPlatform.system}.default;
      installRemoteServer = true;
      extensions = ["nix" "elixir" "dockerfile" "docker-compose"];
      extraPackages = [ pkgs.nixd ];
    };
    stylix.targets.zed.enable = false;

    # Cursor
    xdg.desktopEntries."cursor" = {
      name = "Cursor";
      genericName = "Text Editor";
      exec = "${pkgs.appimage-run}/bin/appimage-run /home/sgiath/nix-root/Cursor-2.0.73-x86_64.AppImage";
    };

    # Tidewave
    xdg.desktopEntries."tidewave" = {
      name = "Tidewave";
      genericName = "AI-powered code editor";
      exec = "${pkgs.appimage-run}/bin/appimage-run /home/sgiath/nix-root/tidewave-app-amd64.AppImage";
    };

    # Codex
    programs.codex = {
      enable = true;
      settings = {
        # untrusted on-failure on-request never
        approval_policy = "on-request";

        tools = {
          web_search = true;
          view_image = true;
        };

        mcp_servers = {
          context7 = {
            url = "https://mcp.context7.com/mcp";
            http_headers = { 
              CONTEXT7_API_KEY = "ctx7sk-a64011f8-3e75-45cb-add9-46fe828f3b52";
            };
          };
        };
      };
    };

    # home.packages = with pkgs; [ ];
  };
}
