{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.programs.voxtype.enable) {
    programs = {
      voxtype = {
        package = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
        model.name = "large-v3-turbo";
        service.enable = true;
        settings = {
          hotkey = {
            enabled = true;
            key = "RIGHTALT";
          };
          whisper.language = "en";
          output = {
            mode = "type";
            fallback_to_clipboard = true;
            type_delay_ms = 0;
          };
          audio = {
            device = "default";
            sample_rate = 16000;
            max_duration_secs = 60;
          };
        };
      };

      waybar.settings.mainBar."custom/voxtype" = {
        exec = "${
          inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan
        }/bin/voxtype status --follow --format json";
        return-type = "json";
        format = "{}";
        tooltip = true;
      };
    };
  };
}
