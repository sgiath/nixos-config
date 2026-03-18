{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.22.1";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-ysj3knicwW9TK2Gr/N5MsXS5Sm8nGMDRc0rNsrMo9mA=";
  };

  npmDepsHash = "sha256-xPHAKcbiuDV4Nyt8HqmKJ0SbzvXu5hfqCRtlTo4tbNE=";

  # Build TypeScript to dist/
  npmBuildScript = "build";

  meta = with lib; {
    description = "Use Claude Code from any ACP client such as Zed";
    homepage = "https://github.com/zed-industries/claude-agent-acp";
    license = licenses.wtfpl;
    maintainers = [ ];
    mainProgram = "claude-agent-acp";
  };
}
