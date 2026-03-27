{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.24.1";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-PUWE+XflwbiKi/l/PpP2BFU42Qn74aC+mLDgQdaKBjQ=";
  };

  npmDepsHash = "sha256-mBDlUUSrJ0G2V4VY765nYxONYd6CG1VnfLgAbJB4sCk=";

  # Build TypeScript to dist/
  npmBuildScript = "build";

  meta = with lib; {
    description = "Use Claude Code from any ACP client such as Zed";
    homepage = "https://github.com/agentclientprotocol/claude-agent-acp";
    license = licenses.wtfpl;
    maintainers = [ ];
    mainProgram = "claude-agent-acp";
  };
}
