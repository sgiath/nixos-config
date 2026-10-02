{
  config,
  lib,
  pkgs,
  osConfig,
  namespace,
  ...
}:
let
  blenderMcp = pkgs.${namespace}.blender-mcp;

  # Cycles renders on AMD GPUs only through HIP, which needs the ROCm build.
  base = if osConfig.sgiath.hardware.gpu == "amd" then pkgs.pkgsRocm.blender else pkgs.blender;

  # `--addons` enables an add-on without a preferences entry, but the MCP
  # add-on's register() reads its preferences, so enable it persistently.
  # Startup scripts load before the extension system, hence the timer.
  mcpStartup = pkgs.writeTextDir "startup/sgiath_blender_mcp.py" ''
    import addon_utils
    import bpy

    _MODULE = "bl_ext.system.mcp"


    def _enable():
        if not addon_utils.check(_MODULE)[1]:
            addon_utils.enable(_MODULE, default_set=True, persistent=True)


    def register():
        bpy.app.timers.register(_enable, first_interval=0.0)


    def unregister():
        if bpy.app.timers.is_registered(_enable):
            bpy.app.timers.unregister(_enable)
  '';

  # Ships the MCP bridge add-on as a system extension; it auto-starts a
  # localhost:9876 socket server in GUI sessions. The add-on refuses to start
  # without online access, which is otherwise a stored preference.
  blenderWithMcp = pkgs.symlinkJoin {
    pname = "blender";
    inherit (base) version;
    paths = [ base ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/blender \
        --set BLENDER_SYSTEM_EXTENSIONS ${blenderMcp.addon} \
        --set BLENDER_SYSTEM_SCRIPTS ${mcpStartup} \
        --add-flags --online-mode
    '';
    meta.mainProgram = "blender";
  };

  blender = if config.sgiath.agents.enable then blenderWithMcp else base;
in
{
  config = lib.mkIf config.sgiath.programs.blender.enable {
    home.packages = [ blender ];

    programs.mcp.servers.blender = lib.mkIf config.sgiath.agents.enable {
      command = lib.getExe blenderMcp;
      # Tools ending in `_for_cli` run this in the background on a .blend file.
      env.BLENDER_PATH = lib.getExe blender;
    };
  };
}
