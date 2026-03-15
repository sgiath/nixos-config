{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-6c6bHuso3diW5ZfHiM2xcxGDTNG0LIL0TZd0MFVpW/E=";
  };

  npmDepsHash = "sha256-UtiIcjgNCYMFrRpO5AlUbOyutJ3ipwIbcpMi2BqawEk=";

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
