{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# let
#   secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
# in
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

    home.packages = [
      # Cursor
      inputs.cursor.packages.${pkgs.stdenv.hostPlatform.system}.cursor
    ];

    # Codex
    programs.codex = {
      enable = true;
      package = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    programs.opencode = {
      enable = true;
      package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
}
