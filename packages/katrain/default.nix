{
  lib,
  stdenv,
  python313Packages,
  fetchFromGitHub,
  fetchPypi,
  appimageTools,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  imagemagick,
  bzip2,
  ocl-icd,
  mtdev,
  openssl,
  zlib,
}:

let
  # KaTrain 1.20 targets the Kivy 2.3 API (kivy.core.audio, ...); nixpkgs ships
  # a Kivy master snapshot that already renamed those modules. Pin the 2.3.1
  # release, which in turn only supports Python <= 3.13. nixpkgs' Cython 3.2
  # dropped the Py2 `long` builtin, so strip its three remaining uses (already
  # gone on Kivy master).
  python3Packages = python313Packages.overrideScope (
    _final: prev: {
      kivy = prev.kivy.overridePythonAttrs (old: {
        version = "2.3.1";
        src = fetchFromGitHub {
          owner = "kivy";
          repo = "kivy";
          rev = "2.3.1";
          hash = "sha256-q8BoF/pUTW2GMKBhNsqWDBto5+nASanWifS9AcNRc8Q=";
        };
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail "setuptools~=69.2.0" "setuptools" \
            --replace-fail "wheel~=0.44.0" "wheel" \
            --replace-fail "cython>=0.29.1,<=3.0.11" "cython" \
            --replace-fail "packaging~=24.0" packaging
          substituteInPlace kivy/lib/mtdev.py \
            --replace-fail "LoadLibrary('libmtdev.so.1')" "LoadLibrary('${lib.getLib mtdev}/lib/libmtdev.so.1')"
          substituteInPlace kivy/weakproxy.pyx \
            --replace-fail "return long(self.__ref__())" "return int(self.__ref__())"
          substituteInPlace kivy/graphics/context_instructions.pyx \
            --replace-fail "cdef long i = long(h * 6.0)" "cdef long i = int(h * 6.0)"
          substituteInPlace kivy/graphics/opengl.pyx \
            --replace-fail "isinstance(indices, (long, int))" "isinstance(indices, int)" \
            --replace-fail "isinstance(data, (long, int))" "isinstance(data, int)"
        '';
        build-system = [
          prev.setuptools
          prev.cython
        ];
      });
    }
  );

  pysgf = python3Packages.buildPythonPackage rec {
    pname = "pysgf";
    version = "1.0.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-aSQxSaksP9oy0/hO30fwFx5dd0eNTyOX/vOA4dHAn6w=";
    };

    build-system = [ python3Packages.hatchling ];
    dependencies = [ python3Packages.chardet ];

    pythonImportsCheck = [ "pysgf" ];

    meta = {
      description = "Simple parser for Go game records (SGF, NGF, GIB)";
      homepage = "https://github.com/sanderland/pysgf";
      license = lib.licenses.mit;
    };
  };

  src = fetchFromGitHub {
    owner = "sanderland";
    repo = "katrain";
    rev = "v${version}";
    hash = "sha256-pvD0k4xAVKJ0oILPBJizJ1jSZESEkeehOGb+Fas9OdI=";
  };

  version = "1.20.0";

  # Upstream bundles KataGo for Linux as an AppImage (OpenCL backend, newer
  # than nixpkgs' katago). FUSE mounting does not work in the sandbox and the
  # AppRun shim hardcodes its own LD_LIBRARY_PATH, so unpack it and ship the
  # inner ELF, patched against nixpkgs libraries. Only libzip.so.4 is kept from
  # the AppImage: nixpkgs' libzip is soname 5.
  katagoAppImage = appimageTools.extract {
    pname = "katago";
    version = "bundled-${version}";
    src = "${src}/katrain/KataGo/katago";
  };
in
python3Packages.buildPythonApplication {
  pname = "katrain";
  inherit version src;
  pyproject = true;

  postPatch = ''
    rm katrain/KataGo/katago.exe katrain/KataGo/*.dll
    install -m755 ${katagoAppImage}/usr/bin/katago katrain/KataGo/katago
    install -m644 ${katagoAppImage}/usr/lib/libzip.so.4 katrain/KataGo/libzip.so.4
  '';

  pythonRelaxDeps = [ "chardet" ];

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    certifi
    chardet
    docutils
    ffpyplayer
    kivy
    pysgf
    screeninfo
    urllib3
    websocket-client
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    imagemagick
  ];

  # Runtime libraries of the bundled katago binary and its libzip.so.4.
  buildInputs = [
    bzip2
    ocl-icd
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  # Kivy writes its config under $HOME on import.
  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  # Launches the KataGo engine (needs an OpenCL device).
  disabledTests = [ "test_ai_strategies" ];

  desktopItems = [
    (makeDesktopItem {
      name = "katrain";
      desktopName = "KaTrain";
      comment = "Go/Baduk/Weiqi playing and teaching app with a variety of AIs";
      exec = "katrain";
      icon = "katrain";
      categories = [
        "Game"
        "BoardGame"
      ];
    })
  ];

  # Upstream only ships a multi-frame .ico; frame 2 is the 256x256 PNG.
  postInstall = ''
    mkdir -p $out/share/icons/hicolor/256x256/apps
    magick 'katrain/img/icon.ico[2]' $out/share/icons/hicolor/256x256/apps/katrain.png
  '';

  meta = {
    description = "Go/Baduk/Weiqi playing and teaching app with a variety of AIs";
    homepage = "https://github.com/sanderland/katrain";
    changelog = "https://github.com/sanderland/katrain/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "katrain";
    platforms = [ "x86_64-linux" ];
  };
}
