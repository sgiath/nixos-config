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
    rev = "3276f71f31c5d5ae74f76220ad5d2048bd31bbc4";
    hash = "sha256-KKEs4Qc8TqgeTfnHg3aOnax8ySwOC8FdoM3/sDqGWkI=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "lightning-0.0.123-beta" = "sha256-gngH0mOC9USzwUGP4bjb1foZAvg6QHuzODv7LG49MsA=";
      "lightning-invoice-0.31.0-beta" = "sha256-gngH0mOC9USzwUGP4bjb1foZAvg6QHuzODv7LG49MsA=";
      "musig2-0.1.0" = "sha256-++1x7uHHR7KEhl8LF3VywooULiTzKeDu3e+0/c/8p9Y=";
      "nip44-0.1.0" = "sha256-u2ALoHQrPVNoX0wjJmQ+BYRzIKsi0G5xPbYjgsNZZ7A=";
      "nostr-types-0.8.0-unstable" = "sha256-MV5/9J45nTuJma/iB/X/mbFDe47ox8tB41+QkqjaQIg=";
    };
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  OPENSSL_NO_VENDOR = 1;

  # Tests often require external relay environment
  doCheck = false;

  meta = with lib; {
    description = "Relay test suite for nostr relays";
    homepage = "https://github.com/mikedilger/relay-tester";
    license = licenses.mit;
    mainProgram = "relay-tester";
  };
}
