{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  autoPatchelfHook,
  cacert,
}:
let
  src = fetchFromGitHub {
    owner = "assimelha";
    repo = "bdui";
    rev = "v0.2.0";
    hash = "sha256-PbJT5MDCjvslXL4MJAZXW2lq3N1T2xyWFhty9AT3YcA=";
  };

  # Fixed-output derivation for node_modules
  node_modules = stdenv.mkDerivation {
    name = "bdui-node-modules";
    inherit src;

    nativeBuildInputs = [
      bun
      cacert
    ];

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    buildPhase = ''
      export HOME=$TMPDIR
      bun install --frozen-lockfile
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-xtsWbeCM+4td6DJ0FWfHstR8Vlag1hUJEi3iRajI3/I=";
  };
in
stdenv.mkDerivation {
  pname = "bdui";
  version = "0.2.0";

  inherit src;

  nativeBuildInputs = [
    bun
    autoPatchelfHook
  ];

  # Don't strip the binary - it breaks bun compiled executables
  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    cp -r ${node_modules}/node_modules .
    chmod -R +w node_modules
    export HOME=$TMPDIR
    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 bdui $out/bin/bdui
    runHook postInstall
  '';

  meta = with lib; {
    description = "A beautiful TUI visualizer for the bd (beads) issue tracker";
    homepage = "https://github.com/assimelha/bdui";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bdui";
  };
}
