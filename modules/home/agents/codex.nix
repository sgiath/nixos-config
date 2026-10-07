{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [
        pkgs.llm-agents.codex
      ]
      ++ (lib.optionals config.sgiath.roles.desktop.enable [ pkgs.llm-agents.chatgpt ]);
      file.".codex/AGENTS.md".source = ./AGENTS.md;
      file.".codex-remote/AGENTS.md".source = ./AGENTS.md;
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe pkgs.llm-agents.codex} --yolo";
    };
  };
}
