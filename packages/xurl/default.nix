{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "xurl";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "xdevplatform";
    repo = "xurl";
    rev = "v${version}";
    hash = "sha256-sL1CIXM3tD9pL8hig+UhBAK7G+4JVOFevHdIyS3DhCU=";
  };

  vendorHash = "sha256-sYGm/Yrcu+i+EsjcJfZcCrp3tvWLxo8cte5YnC0fEbI=";

  postPatch = ''
    substituteInPlace api/client_test.go \
      --replace-fail 'xurl/dev' 'xurl/${version}'
  '';

  ldflags = [
    "-s"
    "-w"
    "-X github.com/xdevplatform/xurl/version.Version=${version}"
  ];

  meta = with lib; {
    description = "Curl-like CLI tool for the X API";
    homepage = "https://github.com/xdevplatform/xurl";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "xurl";
  };
}
