{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "gastown";
  # version = "0.2.6";
  version = "master-6d29f34";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "gastown";
    rev = "6d29f34cd01dc56ed776b850affa2db9bfa537a4";
    # rev = "v${version}";
    hash = "sha256-dDG0vTiCsAWwfCG9hUc5mIwW1i8UqARfrVJTTCUf/RM=";
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
