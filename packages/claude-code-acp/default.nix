{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.13.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-vky2xTrPBidYNfqWeyFvsPPpkaOsToGg/suWHA2v82c=";
  };

  npmDepsHash = "sha256-6wbRFTpPZ9Mk7fspDfyRimvGFqx6U6Jqwu0cQQ3zYEo=";

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
