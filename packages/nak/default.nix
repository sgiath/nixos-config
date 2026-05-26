{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fuse,
  lmdb,
}:

buildGoModule rec {
  pname = "nak";
  version = "0.19.10";

  src = fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${version}";
    hash = "sha256-7j9O8SAig3OMdvtVsxP9Ar1CjUWOhFovKo63S5IbNf8=";
  };

  vendorHash = "sha256-Eeg49ida69AUY5viTHHNgiL8wTXtXRG3kTMiCrU6zCY=";

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
