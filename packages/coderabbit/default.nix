{
  lib,
  stdenv,
  fetchurl,
  unzip,
  glibc,
  patchelf,
}:

stdenv.mkDerivation rec {
  pname = "coderabbit";
  version = "0.3.5";

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
    hash = "sha256-2j4wR6QJ36GsnN7yrBgvCWWb6l7DS29v4Sl4T16H7po=";
  };

  nativeBuildInputs = [ unzip patchelf ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    install -Dm755 coderabbit $out/bin/coderabbit

    # Patch the interpreter only - do not use autoPatchelfHook as it breaks Bun-compiled binaries
    patchelf --set-interpreter "${glibc}/lib/ld-linux-x86-64.so.2" $out/bin/coderabbit

    ln -s $out/bin/coderabbit $out/bin/cr
  '';

  # Don't strip or modify the binary further
  dontStrip = true;
  dontPatchELF = true;

  meta = with lib; {
    description = "AI-powered code review CLI tool";
    homepage = "https://www.coderabbit.ai/cli";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "coderabbit";
  };
}
