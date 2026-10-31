{
  config,
  lib,
  ...
}:

let
  inherit (config.programs.hex) language model package;
  toggleCommand = "${lib.getExe package} dictation toggle";
in
{
  config = lib.mkIf config.programs.hex.enable {
    programs.hex = {
      autostart = true;
      model = "whisper_large_v3_turbo";
      language = "en";
      installModel = true;
      settings.shortcut_mode = "toggle";
    };

    # The service starts before the settings are applied, so a bare `model install`
    # fetches Hex's default model; see UPSTREAM-WORKAROUNDS.md#hex-model-service-selection.
    systemd.user.services.hex-model.Service.ExecStart =
      lib.mkForce "${lib.getExe package} model install ${model} --language ${language}";

    # Hyprland ignores the shortcut Settings records, so the toggle is bound here.
    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + B"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON toggleCommand})")
          ];
        }
      ];
    };
  };
}
