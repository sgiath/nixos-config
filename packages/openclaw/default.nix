{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.23-2";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-a8sfYP0SdypcVb7+kCiKKJxrl/vv3+10TOY+S8qFmO8=";
  };

  sourceRoot = "package";

  postPatch = ''
    if ! ${lib.getExe jq} -e '.dependencies["matrix-js-sdk"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["matrix-js-sdk"] = "^38.2.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    if ! ${lib.getExe jq} -e '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"] = "^0.4.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-3kcBYZIsQBo8cjqAfcnWd3TvL7johbbXa3+VaJQ3Coo=";

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
