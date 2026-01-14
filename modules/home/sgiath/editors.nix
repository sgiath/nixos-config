{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  config = lib.mkIf config.programs.vscode.enable {
    home.sessionVariables = {
      EDITOR = "${pkgs.zed-editor}/bin/zeditor --wait";
      VISUAL = "${pkgs.zed-editor}/bin/zeditor --wait";
    };

    # Zed editor
    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;
      extensions = [
        "nix"
        "elixir"
        "dockerfile"
        "docker-compose"
        "toml"
        "git-firefly"
        "sql"
        "scss"
        "terraform"
        "xml"
        "latex"
        "zig"
        "graphql"
        "mcp-server-context7"
        "mcp-server-github"
        "postgres-context-server"
        "datadog-mcp"
        "mcp-server-shortcut"
        "mcp-server-notion"
      ];
      extraPackages = [ pkgs.nixd ];
    };
    stylix.targets.zed.enable = false;

    home.packages = [
      # Cursor
      inputs.cursor.packages.${pkgs.stdenv.hostPlatform.system}.cursor
    ];
  };
}
