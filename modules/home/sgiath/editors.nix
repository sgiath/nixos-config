{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  zed = pkgs.zed-editor;
  # zed = inputs.zed-editor.packages.${pkgs.stdenv.hostPlatform.system}.default;
  cursor = inputs.cursor.packages.${pkgs.stdenv.hostPlatform.system}.cursor;
in
{
  options.sgiath.editors = {
    enable = lib.mkEnableOption "my editors";
  };

  config = lib.mkIf config.sgiath.editors.enable {
    home.sessionVariables = {
      EDITOR = "${zed}/bin/zeditor --wait";
      VISUAL = "${zed}/bin/zeditor --wait";
    };

    # Zed editor
    programs.zed-editor = {
      enable = true;
      package = zed;
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
    programs.zsh.shellAliases.zed = "${zed}/bin/zeditor";

    home.packages = [ cursor ];
  };
}
