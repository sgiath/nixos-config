{
  lib,
  callPackage,
  stdenv,
  fetchurl,
  fetchzip,
  nodejs,
  p7zip,
  ...
}:
let
  version = "1.210.4";
  pname = "5etools";

  # https://github.com/5etools-mirror-2/5etools-img/releases/tag/v1.210.4
  imgHashes = [
    {
      name = "img-v${version}.zip";
      hash = "sha256-kTNd2EzfEj+XYJ8yqV8bRRhIyPki9k26ocCpv9JuiV8=";
    }
    {
      name = "img-v${version}.z01";
      hash = "sha256-3TP3PW97Qop5nhDWI1rzSfwWwaEWBpXnmZsWMMKapSM=";
    }
    {
      name = "img-v${version}.z02";
      hash = "sha256-g+N7XvASAwnNa65qNa2P4iPkbDH/I0dWelf1AVU4X74=";
    }
    {
      name = "img-v${version}.z03";
      hash = "sha256-0C/9w4nvUnUwjtFAaG0DFzyvB9k9jAX9h7pHVJBnw7o=";
    }
    {
      name = "img-v${version}.z04";
      hash = "sha256-Z9EyT1jFQEvCAjBtxmb/4yZjC48ZpSXlWzSV+PnoxMc=";
    }
    {
      name = "img-v${version}.z05";
      hash = "sha256-SKqRelXWIvLN5F6YPhI42V62s6DAlC/i2BGJDWtIy+Y=";
    }
    {
      name = "img-v${version}.z06";
      hash = "sha256-saFFM5aof1/yUFy8r3H+/mE5te9g7PD0Se4WgPCsDMI=";
    }
    {
      name = "img-v${version}.z07";
      hash = "sha256-uYaC4/9cWSw6uxM/WI2muewLqj97wkjhPz+ixO/L+J4=";
    }
    {
      name = "img-v${version}.z08";
      hash = "sha256-Okh60+yXjWqJ/GPOYORVfMmqJCtC8wEhHhEUjVbySYc=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/${v.name}";
      };
    in
    "cp ${img} ${v.name}"
  );

  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-kIXgWA9KZp/vIGApH5kCnzYr4HB65uG4tQmBcUK8VbM=";
  };

  buildInputs = [
    nodejs
    p7zip
  ];

  buildPhase = ''
    # copy images
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # unpack images
    7z x -aoa img-v${version}.zip

    # remove ZIP files
    rm -f img-v*

    # link Node deps
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    # generate service worker
    npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
