{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fuse,
  lmdb,
}:

buildGoModule rec {
  pname = "nak";
  version = "0.18.4";

  src = fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${version}";
    hash = "sha256-X3TuG1yzydJiFLFWP8HOtylonb7hcZ13djpuTO8fAOY=";
  };

  vendorHash = "sha256-sn2TfwsI4qGIymxtz59uD/bHaRrtTzNaZgvSDmWfV3U=";

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
