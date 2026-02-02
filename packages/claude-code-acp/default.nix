{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-6z0929OquI1s6EtQFjxel1p5dF/ep2hnVGLgKjudj88=";
  };

  npmDepsHash = "sha256-6DS1e9KxM+E6dj49xucxwXJnXbw2ILLe3fNLQyDpt0w=";

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
