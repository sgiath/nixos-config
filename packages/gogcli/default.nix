{
  lib,
  buildGo127Module,
  fetchFromGitHub,
}:

buildGo127Module rec {
  pname = "gogcli";
  version = "0.34.1";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-ocC+A63GLrZQA3mXEPjIfsM7Af9NiYjGF8DZI/2yNS0=";
  };

  vendorHash = "sha256-MAbbCLdoOLWer7HO3+RZJuN10gLeTgN6/CbNn6pzGwQ=";

  env.CGO_ENABLED = 0;

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steipete/gogcli/internal/cmd.version=v${version}"
    "-X github.com/steipete/gogcli/internal/cmd.commit=nix"
    "-X github.com/steipete/gogcli/internal/cmd.date=1970-01-01T00:00:00Z"
  ];

  meta = with lib; {
    description = "Google Suite CLI: Gmail, GCal, GDrive, GContacts";
    homepage = "https://github.com/steipete/gogcli";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "gog";
  };
}
