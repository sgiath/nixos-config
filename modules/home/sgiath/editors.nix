{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
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

      # Claude Code
      pkgs.claude-code
      pkgs.${namespace}.claude-code-acp
      pkgs.${namespace}.openspec
      pkgs.${namespace}.ntm
      pkgs.python3

      # gas town
      pkgs.${namespace}.gastown

      # Beads
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.beads-viewer.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.${namespace}.bdui
      pkgs.${namespace}.lazybeads
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
