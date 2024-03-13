{ config, ... }:
let
  base16-polybar = config.lib.stylix.colors {
    template = builtins.readFile ./polybar/theme.mustache;
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
      monospace = "${config.stylix.fonts.monospace.name}:size=10:style=Bold;2"

      ; actual config
      ${builtins.readFile ./polybar/polybar.ini}
    '';
  };

  xsession = {
    enable = true;
    initExtra = ''
      polybar main0 &
      polybar main1 &
      polybar main2 &
    '';
  };
}
