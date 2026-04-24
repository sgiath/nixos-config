{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ pkgs.cursor-cli ];

    programs.zsh.shellAliases = {
      ca = "${lib.getExe pkgs.cursor-cli} --yolo --approve-mcps --trust";
    };
  };
}
