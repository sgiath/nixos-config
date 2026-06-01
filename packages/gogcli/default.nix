{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "gogcli";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-ntJn0TTtnNeIPX4ZQQ4Zb0SJzqkjnJHoFzVpO2wHfZk=";
  };

  vendorHash = "sha256-fkvMTJmYRsknDDffrZq2L2GRYDozwPX0yv7K84n5a84=";

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
