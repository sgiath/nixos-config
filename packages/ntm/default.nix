{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "ntm";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "ntm";
    rev = "v${version}";
    hash = "sha256-bfFk2avBbZHnVyl1GmpM9+IRQX3+Q/LaFGliWAqC13M=";
  };

  vendorHash = "sha256-k8n+gUW9wadpmoeyj4qiJP5cYzT5Fbcn6wTWqBM1J8w=";

  subPackages = [ "cmd/ntm" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Dicklesworthstone/ntm/internal/cli.Version=${version}"
    "-X github.com/Dicklesworthstone/ntm/internal/cli.BuiltBy=nix"
  ];

  meta = with lib; {
    description = "Named Tmux Manager - Orchestrate AI coding agents in tmux sessions";
    homepage = "https://github.com/Dicklesworthstone/ntm";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "ntm";
  };
}
