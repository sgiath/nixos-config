{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.12.6";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-RJ3nl86fGEEh4RgZoLiyz9XOC4wlP7WxuJzavZLsjMI=";
  };

  npmDepsHash = "sha256-3JLqokF1nk41S198NzYDT6xH8QiRm1yPBotyBnXu3E0=";

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
