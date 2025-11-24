{
  inputs,
  pkgs,
  namespace,
  ...
}:
let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.build
    ps.cffi
    ps.click
    ps."dbus-python"
    ps."kde-material-you-colors"
    ps.libsass
    ps.loguru
    ps."material-color-utilities"
    ps.materialyoucolor
    ps.numpy
    ps.pillow
    ps.psutil
    ps.pycairo
    ps.pygobject3
    ps.pywayland
    ps.setproctitle
    ps."setuptools-scm"
    ps.tqdm
    ps.wheel
    ps."pyproject-hooks"
    ps.opencv4
  ]);

  qmlPath = pkgs.lib.makeSearchPath pkgs.kdePackages.qtbase.qtQmlPrefix [
    pkgs.kdePackages.qtpositioning
    pkgs.kdePackages.qtbase
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qtsensors
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qtwayland
    pkgs.kdePackages.qt5compat
    pkgs.kdePackages.qtimageformats
    pkgs.kdePackages.qtquicktimeline
    pkgs.kdePackages.qttools
    pkgs.kdePackages.qttranslations
    pkgs.kdePackages.qtvirtualkeyboard
    pkgs.kdePackages.qtwebsockets
    pkgs.kdePackages.kirigami.unwrapped
  ];

  quickshell-with-qtpositioning = pkgs.symlinkJoin {
    name = "quickshell-with-qtpositioning";
    paths = [ inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Create a fake venv structure for compatibility with scripts that source activate
      mkdir -p $out/venv/bin
      cat > $out/venv/bin/activate <<'EOF'
        # Fake activate script for Nix Python environment
        # The Python environment is already available in PATH
        # Provide a deactivate function for compatibility
        deactivate() {
            # In a real venv, this would restore the old PATH
            # Since we're using Nix, there's nothing to deactivate
            :
        }
        EOF

      # Wrap both quickshell and qs commands with Qt module paths and Python
      for binary in quickshell qs; do
        if [ -f "$out/bin/$binary" ]; then
          wrapProgram "$out/bin/$binary" \
            --prefix QML_IMPORT_PATH : "${qmlPath}" \
            --prefix QML2_IMPORT_PATH : "${qmlPath}" \
            --prefix PATH : "${pythonEnv}/bin" \
            --set ILLOGICAL_IMPULSE_VIRTUAL_ENV "$out/venv"
        fi
      done
    '';
  };
in
{
  # Qt/KDE packages required for QuickShell functionality
  home.packages = with pkgs; [
    # Core utilities
    cava
    lxqt.pavucontrol-qt
    wireplumber
    libdbusmenu-gtk3
    playerctl
    brightnessctl
    ddcutil
    axel
    bc
    cliphist
    libqalculate

    # QuickShell with QtPositioning support (wrap both qs and quickshell)
    quickshell-with-qtpositioning

    # Qt packages for QuickShell functionality
    kdePackages.qt5compat # Visual effects (blur, etc.)
    kdePackages.qtbase
    kdePackages.qtdeclarative
    kdePackages.qtimageformats # WEBP and other image formats
    kdePackages.qtmultimedia # Media playback
    kdePackages.qtpositioning
    kdePackages.qtquicktimeline
    kdePackages.qtsensors
    kdePackages.qtsvg # SVG image support
    kdePackages.qttools
    kdePackages.qttranslations
    kdePackages.qtvirtualkeyboard
    kdePackages.qtwayland
    kdePackages.qtwebsockets
    kdePackages.syntax-highlighting
    kdePackages.kirigami.unwrapped

    # Themes and icons
    adw-gtk3
    pkgs.${namespace}.illogical-impulse-oneui4-icons
    papirus-icon-theme # Primary icon theme
    adwaita-icon-theme # GNOME fallback icons
    hicolor-icon-theme # Base icon theme (required by most themes)
    gnome-icon-theme # Additional GNOME icon coverage
    kdePackages.breeze-icons # KDE Breeze icons (required by Papirus inheritance)

    # Fonts
    pkgs.${namespace}.material-symbols
    rubik
    # nurPkgs.repos.skiletro.gabarito
    nerd-fonts.ubuntu
    nerd-fonts.ubuntu-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    nerd-fonts.fantasque-sans-mono
    nerd-fonts.mononoki
    nerd-fonts.space-mono
  ];
  qt.enable = true;
  programs.quickshell = {
    enable = true;
    package = quickshell-with-qtpositioning;
    activeConfig = "default";
    configs.default = ./quickshell;
  };
}
