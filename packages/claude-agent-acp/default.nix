{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.23.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-uWs5R+9GjHy4s6HW7aHpyQJdlULCurMawyao4tzq6qA=";
  };

  npmDepsHash = "sha256-26zBN017e0kYR8gtiXkKBeIZbsyOmPy7yaaMZeJZzRY=";

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
