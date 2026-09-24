{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "xurl";
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "xdevplatform";
    repo = "xurl";
    rev = "v${version}";
    hash = "sha256-A+vvHcXp5CYjO/DCENqK1yAF+TbFjRcqHkW3LYhQwhk=";
  };

  vendorHash = "sha256-b38O+w1E236YNH0Ut0c01ymuwIHBe3wts6UhCO6ViOo=";
  proxyVendor = true;

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
