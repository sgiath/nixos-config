{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.programs.vscode.enable {
    programs.vscode = {
      profiles.default.userSettings = {
        "editor.tabSize" = 2;
        "editor.minimap.enabled" = false;
        "security.workspace.trust.untrustedFiles" = "open";
        "explorer.confirmDelete" = false;
        "editor.wordWrapColumn" = 98;
        "github.copilot.enable"."*" = false;
      };
    };

    stylix.targets.vscode.enable = false;
  };
}
