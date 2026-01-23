{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  libsecret,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "coderabbit";
  version = "0.3.5";

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
    hash = "sha256-2j4wR6QJ36GsnN7yrBgvCWWb6l7DS29v4Sl4T16H7po=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
  ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    install -Dm755 coderabbit $out/bin/coderabbit-unwrapped

    # Wrap with LD_LIBRARY_PATH for libsecret (credential storage)
    makeWrapper $out/bin/coderabbit-unwrapped $out/bin/coderabbit \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libsecret ]}"

    ln -s $out/bin/coderabbit $out/bin/cr
  '';

  dontStrip = true;

  meta = with lib; {
    description = "AI-powered code review CLI tool";
    homepage = "https://www.coderabbit.ai/cli";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "coderabbit";
  };
}
