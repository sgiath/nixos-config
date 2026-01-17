{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-pG4iO2jVuzrSg7UfmOd2/gxsRKXLni8AWzpFEqtfu1s=";
  };

  npmDepsHash = "sha256-AmQCjPBcTX+0HRpow8B+nBQ/uqrti6QmWqErX2FI9+Y=";

  # Build TypeScript to dist/
  npmBuildScript = "build";

  meta = with lib; {
    description = "Use Claude Code from any ACP client such as Zed";
    homepage = "https://github.com/zed-industries/claude-code-acp";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "claude-code-acp";
  };
}
