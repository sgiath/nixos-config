{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.editors = {
    enable = lib.mkEnableOption "my editors";
  };

  config = lib.mkIf config.sgiath.editors.enable {
    home.sessionVariables = {
      EDITOR = "${lib.getExe pkgs.zed-editor} --wait";
      VISUAL = "${lib.getExe pkgs.zed-editor} --wait";
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
        "sql"
        "scss"
        "terraform"
        "xml"
        "latex"
        "zig"
        "graphql"
      ];
      extraPackages = [
        pkgs.nixd
        pkgs.nil
      ];
    };
    stylix.targets.zed.enable = false;
    programs.zsh.shellAliases.zed = "${lib.getExe pkgs.zed-editor}";
  };
}
