{
  lib,
  stdenv,
  importNpmLock,
  nodejs,
}:

let
  # Same tree `npm install --prefix` leaves under ~/.t3/tools/<name>/<version>,
  # including the sentinel T3 checks before it would install the tool itself.
  tool =
    name: entry:
    stdenv.mkDerivation (finalAttrs: {
      pname = name;
      version = (lib.importJSON ./${name}/package-lock.json).packages."node_modules/${name}".version;
      src = ./${name};

      npmDeps = importNpmLock { npmRoot = ./${name}; };
      npmRebuildFlags = [ "--ignore-scripts" ];
      nativeBuildInputs = [
        nodejs
        importNpmLock.npmConfigHook
      ];

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        test -e node_modules/${name}/${entry}
        echo ${finalAttrs.version} > .install-complete

        mkdir -p $out/${name}
        cp -r . $out/${name}/${finalAttrs.version}

        runHook postInstall
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck

        cd $out/${name}/${finalAttrs.version}
        if [ -d node_modules/node-datachannel ]; then
          timeout 30 node -e '
            const { PeerConnection, cleanup } = require("node-datachannel");
            new PeerConnection("check", { iceServers: [] }).close();
            cleanup();
          '
        fi

        runHook postInstallCheck
      '';
    });

  tools = [
    (tool "expo-device-hub" "dist/server/cli.mjs")
    (tool "agent-device" "bin/agent-device.mjs")
  ];
in
stdenv.mkDerivation {
  pname = "t3code-nightly-device-tools";
  version = lib.concatMapStringsSep "-" (t: t.version) tools;

  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (t: "ln -s ${t}/${t.pname} $out/${t.pname}") tools}
  '';

  passthru = { inherit tools; };

  meta = {
    description = "Device hub and agent-device npm tools pinned by the T3 Code nightly, laid out as T3 installs them";
    homepage = "https://github.com/expo/expo-device-hub";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
