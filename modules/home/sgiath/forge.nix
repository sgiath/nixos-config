{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  forge = inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf (config.sgiath.agents.enable && false) {
    home.packages = [ forge ];

    programs.zsh.initContent = lib.mkAfter ''
      if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
        eval "$(${lib.getExe forge} zsh plugin)"
      fi

      if [[ -z "$_FORGE_THEME_LOADED" ]]; then
        eval "$(${lib.getExe forge} zsh theme)"
      fi
    '';
  };
}
