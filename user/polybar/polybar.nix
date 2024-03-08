{ config, ... }:
let
  base16-polybar = config.lib.stylix.colors {
    template = builtins.readFile ./theme.mustache;
  };
in
{
  services.polybar = {
    enable = true;
    script = "";
    extraConfig = ''
      ; generated theme
      include-file = ${base16-polybar}

      [fonts]
      regular = "${config.stylix.fonts.sansSerif.name}"
      monospace = "${config.stylix.fonts.monospace.name}"

      ; actual config
      ${builtins.readFile ./polybar.ini}
    '';
  };

  xsession = {
    enable = true;
    initExtra = ''
      polybar main1 &
    '';
  };
}
