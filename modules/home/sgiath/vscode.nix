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
      };
    };

    stylix.targets.vscode.enable = false;
  };
}
