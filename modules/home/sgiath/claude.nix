{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.agents.enable && false) {
    programs.claude-code = {
      enable = false;
      package = pkgs.claude-code;
    };

    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.claude-code} --dangerously-skip-permissions";
    };
  };
}
