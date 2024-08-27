{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pyaudio,
  pythonOlder,
  rns,
  lxmf,
  kivy,
  plyer,
  pillow,
  qrcode,
  materialyoucolor,
  setuptools,
}:

buildPythonPackage rec {
  pname = "sbapp";
  version = "0.9.1";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "markqvist";
    repo = "Sideband";
    rev = "refs/tags/${version}";
    hash = "sha256-YC4CEF2VSPq9bHk01lILbd8x0CkrkAAt7L8+MM3XzjY=";
  };

  postInstall = ''
    find . -name "*.kv" -exec cp --parents {} $out/lib/python3.12/site-packages/ \;
  '';

  build-system = [ setuptools ];

  dependencies = [
    rns
    lxmf
    kivy
    plyer
    pillow
    qrcode
    materialyoucolor
    pyaudio
  ];

  # Module has no tests
  doCheck = false;

  pythonImportsCheck = [ "sbapp" ];

  meta = with lib; {
    description = "LXMF client for Android, Linux and macOS allowing you to communicate with people or LXMF-compatible systems over Reticulum networks using LoRa, Packet Radio, WiFi, I2P, or anything else Reticulum supports.";
    homepage = "https://github.com/markqvist/Sideband";
    changelog = "https://github.com/markqvist/Sideband/releases/tag/${version}";
    license = licenses.acsl14;
    maintainers = with maintainers; [ fab ];
  };
}
