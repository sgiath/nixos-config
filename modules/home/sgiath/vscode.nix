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
      };
    };

    stylix.targets.vscode.enable = false;
  };
}
