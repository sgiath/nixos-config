{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "relay-tester";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "mikedilger";
    repo = "relay-tester";
    rev = "6e4960cfd4854dc652deccb0e005865f7c522f5f";
    hash = "sha256-n0RYDNOSGAnt8fNDFn/SAnl1DEaObaM9ABlCHok5IM4=";
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
