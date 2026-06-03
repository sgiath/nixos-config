{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.agents.enable && false) {
    home.packages = [ pkgs.llm-agents.forgecode ];

    programs.zsh.initContent = lib.mkAfter ''
      if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
        eval "$(${lib.getExe pkgs.llm-agents.forgecode} zsh plugin)"
      fi

      if [[ -z "$_FORGE_THEME_LOADED" ]]; then
        eval "$(${lib.getExe pkgs.llm-agents.forgecode} zsh theme)"
      fi
    '';
  };
}
