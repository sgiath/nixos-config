{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "gastown";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "gastown";
    rev = "v${version}";
    hash = "sha256-mtouqawxbaLruvBNuXSyYCwREEg1mi0SFQRLfOdJQxI=";
  };

  vendorHash = "sha256-ripY9vrYgVW8bngAyMLh0LkU/Xx1UUaLgmAA7/EmWQU=";

  subPackages = [ "cmd/gt" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steveyegge/gastown/internal/cmd.Version=${version}"
    "-X github.com/steveyegge/gastown/internal/cmd.Build=nix"
  ];

  meta = with lib; {
    description = "Multi-agent orchestration system for Claude Code with persistent work tracking";
    homepage = "https://github.com/steveyegge/gastown";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "gt";
  };
}
