{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.vscode.enable {
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

    xdg.desktopEntries = {
      "cursor" = {
        name = "Cursor";
        genericName = "Text Editor";
        exec = "${pkgs.appimage-run}/bin/appimage-run /home/sgiath/nix-root/Cursor-1.0.0-x86_64.AppImage";
      };
    };
  };
}
