{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fuse,
  lmdb,
}:

buildGoModule rec {
  pname = "nak";
  version = "0.19.11";

  src = fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${version}";
    hash = "sha256-V/PQxEoKSJgSzDPdbAWGEnm20eFg72fMg6eP7qpumDQ=";
  };

  vendorHash = "sha256-CsXSX7IBXmaEatGOAdg9ytVX+rKap5VOqtGoWe/xK4s=";

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
