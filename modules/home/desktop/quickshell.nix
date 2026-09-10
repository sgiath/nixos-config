{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
# In-repo Quickshell shell (`qs -c sgiath`). QML lives in ./quickshell; colors,
# fonts and the wallpaper come from Home Manager through a generated JSON the
# shell watches, so the QML side never hardcodes the palette.
let
  cfg = config.sgiath.desktop.quickshell;
  live = cfg.live;

  colors = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;
  wallpaper = config.sgiath.desktop.wallpaper;

  theme = (pkgs.formats.json { }).generate "sgiath-shell-theme.json" {
    colors = lib.genAttrs (map (i: "base0${i}") (lib.stringToCharacters "0123456789ABCDEF")) (
      name: colors.${name}
    );
    # Qt renders the shared size visibly smaller than terminal/GTK apps; +2 lands
    # it at the same apparent size.
    font = {
      family = fonts.monospace.name;
      size = fonts.sizes.desktop + 2;
    };
    # Store path so the file name (and thus the image/video suffix) survives.
    wallpaper = if wallpaper == null then "" else "${wallpaper}";
    ignoredOutputs = cfg.ignoredOutputs;
    # Runs desktop entries marked Terminal=true.
    terminal = lib.getExe pkgs.kitty;
    pinned = cfg.pinned;
  };

  # packages/quickshell: nixpkgs quickshell wrapped with QtMultimedia for the
  # video wallpaper.
  quickshell = pkgs.${namespace}.quickshell;

  qmlTooling = pkgs.kdePackages.qtdeclarative; # qmlls, qmlformat
  qmlImportPath = lib.concatStringsSep ":" [
    "${quickshell}/lib/qt-6/qml"
    "${quickshell.qtmultimedia}/lib/qt-6/qml"
    "${qmlTooling}/lib/qt-6/qml"
  ];
in
{
  config = lib.mkIf config.programs.quickshell.enable {
    programs.quickshell = {
      package = quickshell;
      systemd.enable = true;
      activeConfig = "sgiath";
      configs.sgiath =
        if live then
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home/desktop/quickshell"
        else
          ./quickshell;
    };

    xdg.configFile."sgiath-shell/theme.json".source = theme;

    systemd.user.services.quickshell.Unit = {
      PartOf = [ config.wayland.systemd.target ];
      # Live mode reloads QML on save; the theme file is a store symlink whose
      # target flips on switch, which the file watcher does not see.
      X-Restart-Triggers = [
        "${theme}"
      ]
      ++ lib.optional (!live) "${config.xdg.configFile."quickshell/sgiath".source}";
    };

    home = lib.mkIf live {
      packages = [ qmlTooling ];
      sessionVariables.QML_IMPORT_PATH = qmlImportPath;
    };

    wayland.windowManager.hyprland.settings.layer_rule = [
      {
        name = "sgiath-shell";
        match.namespace = "^sgiath-.*";
        no_anim = true;
        ignore_alpha = 0.5;
        blur = true;
        blur_popups = true;
      }
      # Nothing sits under the background layer; blurring a screen-sized
      # surface that repaints at video rate is pure GPU waste.
      {
        name = "sgiath-wallpaper";
        match.namespace = "^sgiath-wallpaper$";
        blur = false;
        blur_popups = false;
      }
    ];
  };
}
