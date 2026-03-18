{
  lib,
  stdenv,
  fetchzip,
  curl,
  libxml2,
  openssl,
}:
let
  beakerRev = "232143960505b156e8388017a866a89230224105";
  beaker = stdenv.mkDerivation {
    pname = "beaker";
    version = "unstable-${lib.substring 0 8 beakerRev}";

    src = fetchzip {
      url = "https://git.bwaaa.monster/beaker/snapshot/beaker-${beakerRev}.tar.gz";
      hash = "sha256-dGL0jdJZ5t3V2MBAoPWS05r5D4vsZrfMyqmyGR/ctCI=";
    };

    enableParallelBuilding = true;

    makeFlags = [
      "CC=${stdenv.cc.targetPrefix}cc"
    ];

    installFlags = [
      "INSTALL_PREFIX=${placeholder "out"}/"
      "LDCONFIG=true"
    ];
  };
  rev = "3e0365e7588f0f8f5dbd4a4251806f652b31d7b7";
in
stdenv.mkDerivation {
  pname = "omnisearch";
  version = "unstable-${lib.substring 0 8 rev}";

  src = fetchzip {
    url = "https://git.bwaaa.monster/omnisearch/snapshot/omnisearch-${rev}.tar.gz";
    hash = "sha256-869+vYIlxwxDLuSmjtn73A7wclGufVfiKyCMonEB0aA=";
  };

  buildInputs = [
    beaker
    curl
    libxml2
    openssl
  ];

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '/usr/include/libxml2' '${libxml2.dev}/include/libxml2'
  '';

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/omnisearch $out/libexec/omnisearch
    install -Dm644 example-config.ini $out/share/omnisearch/config.ini
    cp -r templates $out/share/omnisearch/templates
    cp -r static $out/share/omnisearch/static

    mkdir -p $out/bin
    printf '%s\n' \
      '#!${stdenv.shell}' \
      "data_dir=\"''${OMNISEARCH_DATA_DIR:-$out/share/omnisearch}\"" \
      'cd "$data_dir"' \
      "exec $out/libexec/omnisearch \"\$@\"" \
      > $out/bin/omnisearch
    chmod +x $out/bin/omnisearch

    runHook postInstall
  '';

  meta = with lib; {
    description = "Modern lightweight metasearch engine written in C";
    homepage = "https://git.bwaaa.monster/omnisearch/";
    license = licenses.gpl1Plus;
    mainProgram = "omnisearch";
    platforms = platforms.linux;
  };
}
