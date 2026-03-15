{
  lib,
  fetchurl,
  stdenv,
}:

let
  pname = "slate";
  version = "1.0.16";

  sourceKey =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      if stdenv.hostPlatform.isMusl then "x86_64-linux-musl" else "x86_64-linux"
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      if stdenv.hostPlatform.isMusl then "aarch64-linux-musl" else "aarch64-linux"
    else
      throw "slate is only available for x86_64-linux and aarch64-linux";

  packageNames = {
    "x86_64-linux" = "slate-linux-x64";
    "x86_64-linux-musl" = "slate-linux-x64-musl";
    "aarch64-linux" = "slate-linux-arm64";
    "aarch64-linux-musl" = "slate-linux-arm64-musl";
  };

  sourceHashes = {
    "x86_64-linux" =
      "sha512-EWFeRDkw0sGZR3WbCsAMarzI2ifQomwfnO3zTZp/KVrXRHgORJjXUD0GmpxCrpg4vh6nKoB6fxSW4YpodwQlaw==";
    "x86_64-linux-musl" =
      "sha512-TCFOxe19570owUJDpR9nctE3d1BriTzOlmMhC9Ybu/YwBJ4mbVdJBc1BTQUN/2+Fzo+1WhW4WfXMbDf9oFmk8Q==";
    "aarch64-linux" =
      "sha512-bGP4H0QWahEalfjKM+8Jk8PoH8xs9Yo+iY+EQI7XXOUk61rmBW25wrMxTW1Llk9JGyY3fBSZb/ME93OgGTpSPA==";
    "aarch64-linux-musl" =
      "sha512-vq88QOMIIVywGjgPeQSoMQcKnCIlwTVk1dt3BI+T0iVbijhkblx5BnumftweRuF1XfigDWF0EaXviclfvfLrTA==";
  };

  packageName = packageNames.${sourceKey};

  src = fetchurl {
    url = "https://registry.npmjs.org/@randomlabs/${packageName}/-/${packageName}-${version}.tgz";
    hash = sourceHashes.${sourceKey};
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontBuild = true;
  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
            runHook preInstall

            tar -xzf $src
            mkdir -p $out/bin
            mkdir -p $out/libexec/${packageName}
            cp -R package/. $out/libexec/${packageName}
            chmod +x $out/libexec/${packageName}/bin/slate

        cat > $out/bin/slate <<EOF
    #!${stdenv.shell}
    exec $out/libexec/${packageName}/bin/slate "\$@"
    EOF
                    chmod +x $out/bin/slate

                    runHook postInstall
  '';

  meta = {
    description = "Random Labs Slate CLI";
    homepage = "https://www.npmjs.com/package/@randomlabs/slate";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
