{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.26.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    rev = "v${version}";
    hash = "sha256-2G8gjMCnk3W1I2+4sNsumL15ts9bLXAOMguCmwnzWSA=";
  };

  npmDepsHash = "sha256-msm4L8Yi7ma2eHOYXbZx+Qtrx4TzK7FV3HpVzRhQ19o=";

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
