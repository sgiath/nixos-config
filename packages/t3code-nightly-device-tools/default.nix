{
  lib,
  stdenv,
  fetchurl,
  importNpmLock,
  nodejs,
}:

let
  sources = lib.importJSON ./sources.json;
  locked =
    root: name: (lib.importJSON ./${root}/package-lock.json).packages."node_modules/${name}".version;

  # node-datachannel's install script downloads this prebuilt, falling back to
  # a cmake build; neither works in the sandbox.
  datachannelVersion = locked "expo-device-hub" "node-datachannel";
  datachannel =
    assert lib.assertMsg (datachannelVersion == sources.node-datachannel.version)
      "t3code-nightly-device-tools: sources.json pins node-datachannel ${sources.node-datachannel.version}, the lockfile ${datachannelVersion}; rerun update.sh";
    fetchurl {
      url = "https://github.com/murat-dogan/node-datachannel/releases/download/v${datachannelVersion}/node-datachannel-v${datachannelVersion}-napi-v8-linux-${
        {
          x86_64-linux = "x64";
          aarch64-linux = "arm64";
        }
        .${stdenv.hostPlatform.system}
      }.tar.gz";
      hash = sources.node-datachannel.${stdenv.hostPlatform.system};
    };

  # Same tree `npm install --prefix` leaves under ~/.t3/tools/<name>/<version>,
  # including the sentinel T3 checks before it would install the tool itself.
  tool =
    name: entry:
    stdenv.mkDerivation (finalAttrs: {
      pname = name;
      version = locked name name;
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

        if [ -d node_modules/node-datachannel ]; then
          tar -xzf ${datachannel} -C node_modules/node-datachannel
        fi
        test -e node_modules/${name}/${entry}
        echo ${finalAttrs.version} > .install-complete

        mkdir -p $out/${name}
        cp -r . $out/${name}/${finalAttrs.version}

        runHook postInstall
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
