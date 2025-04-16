{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.programs.vscode.enable {
    programs.vscode = {
      profiles.default.userSettings = {
        "security.workspace.trust.untrustedFiles" = "open";
        "editor.tabSize" = 2;
        "editor.minimap.enabled" = false;
        "explorer.confirmDelete" = false;
        "editor.wordWrapColumn" = 98;
        # Augment needs to have it disabled
        "github.copilot.enable"."*" = false;
        "makefile.configureOnOpen" = true;
      };
    };

    stylix.targets.vscode.enable = false;
  };
}
