{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    # intentionally not using codex module since codex really wants to update its config in place
    # and managing it through Nix is more pain then benefits

    home = {
      packages = [ pkgs.llm-agents.codex ];
      file.".codex/AGENTS.md".source = ./AGENTS.md;
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe pkgs.llm-agents.codex} --yolo";
    };
  };
}
