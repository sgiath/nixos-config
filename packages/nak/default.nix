{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fuse,
  lmdb,
}:

buildGoModule rec {
  pname = "nak";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${version}";
    hash = "sha256-jewvap5dYDpW7kqN2BvJuaqXG8C+gya9y6NxwPQhR4I=";
  };

  vendorHash = "sha256-gDBDN+loVtsTTj8J1sFlWqMgcdlKepj/16hLkiQEmTs=";

  buildInputs = [
    lmdb
    fuse
  ];

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
  ];

  # tests require network access
  doCheck = false;

  meta = with lib; {
    description = "The nostr army knife - a command line tool for all things nostr";
    homepage = "https://github.com/fiatjaf/nak";
    license = licenses.unlicense;
    maintainers = [ ];
    mainProgram = "nak";
  };
}
