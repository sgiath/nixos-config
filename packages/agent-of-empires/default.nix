{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  tmux,
  makeWrapper,
}:

rustPlatform.buildRustPackage rec {
  pname = "agent-of-empires";
  version = "0.10.1";

  src = fetchFromGitHub {
    owner = "njbrake";
    repo = "agent-of-empires";
    rev = "v${version}";
    hash = "sha256-2wSj7lyqaIRigMm1zOClNUuSFUxsMTMCsCHV4FJ546o=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ openssl ];

  OPENSSL_NO_VENDOR = 1;

  # Tests require git in sandbox which is difficult to set up
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/aoe --prefix PATH : ${lib.makeBinPath [ tmux ]}
  '';

  meta = with lib; {
    description = "Terminal session manager for AI coding agents";
    homepage = "https://github.com/njbrake/agent-of-empires";
    license = licenses.mit;
    mainProgram = "aoe";
  };
}
