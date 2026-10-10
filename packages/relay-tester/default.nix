{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage {
  pname = "relay-tester";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "mikedilger";
    repo = "relay-tester";
    rev = "a8483f82f4965841faa92fae02105d4fd67d9117";
    hash = "sha256-e424+SgzE5ptT78ZzOKVR736e36vwGzsVehK1rpVPqk=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "nip44-0.1.0" = "sha256-u2ALoHQrPVNoX0wjJmQ+BYRzIKsi0G5xPbYjgsNZZ7A=";
      "nostr-types-0.8.0-unstable" = "sha256-MV5/9J45nTuJma/iB/X/mbFDe47ox8tB41+QkqjaQIg=";
    };
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  OPENSSL_NO_VENDOR = 1;

  meta = with lib; {
    description = "Relay test suite for nostr relays";
    homepage = "https://github.com/mikedilger/relay-tester";
    license = licenses.mit;
    mainProgram = "relay-tester";
  };
}
