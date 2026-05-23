{
  autoPatchelfHook,
  buildNpmPackage,
  fetchurl,
  lib,
  makeWrapper,
  nodejs_22,
  stdenv,
}:

(buildNpmPackage.override { nodejs = nodejs_22; }) rec {
  pname = "qmd";
  version = "2.5.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@tobilu/qmd/-/qmd-${version}.tgz";
    hash = "sha512-kuF+6eGdpWAsgYnRB7O8AEp5XpgEbagTuzcZPE8NbtGjPpWWhb4f35DkoV31lyfe5Ip2RVL6jZoTTCYndu7o/g==";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-dqyJiC4xImCRJO/GKL/FrN56oZW1TI4+Mhc01OCptnc=";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontNpmBuild = true;

  npmFlags = [
    "--legacy-peer-deps"
  ];

  postInstall = ''
    packageRoot="$out/lib/node_modules/@tobilu/qmd"

    cp ${./package-lock.json} "$packageRoot/package-lock.json"

    find "$packageRoot/node_modules/@node-llama-cpp" -mindepth 1 -maxdepth 1 \
      ! -name linux-x64 \
      -exec rm -rf {} +

    rm "$out/bin/qmd"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/qmd" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      --add-flags "$packageRoot/dist/cli/qmd.js"

    test -f "$packageRoot/package-lock.json"
  '';

  meta = {
    description = "On-device hybrid search for markdown files with BM25, vector search, and LLM reranking";
    homepage = "https://github.com/tobi/qmd";
    license = lib.licenses.mit;
    mainProgram = "qmd";
    platforms = lib.platforms.linux;
  };
}
