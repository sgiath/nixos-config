{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.16.1";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-/HeAz0jdXhLhYGcwTgthrE7cGjKjro30GQUmAn4egXs=";
  };

  npmDepsHash = "sha256-poTtwIIPHcgQ2uyIUIWVOpHbdDIzVgympa7aHtuSMok=";

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
