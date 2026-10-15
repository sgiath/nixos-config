{
  writeShellApplication,
  runCommand,
  coreutils,
  findutils,
  gnused,
  jq,
  ffmpeg,
}:
let
  fix-video = writeShellApplication {
    name = "fix-video";
    runtimeInputs = [
      coreutils
      findutils
      gnused
      jq
      ffmpeg
    ];
    text = builtins.readFile ./fix-video.sh;
    # nix build '.#fix-video.tests.cli'
    passthru.tests.cli =
      runCommand "fix-video-test"
        {
          nativeBuildInputs = [
            coreutils
            findutils
            jq
            ffmpeg
          ];
        }
        ''
          bash ${./test.sh} ${fix-video}/bin/fix-video
          touch $out
        '';
  };
in
fix-video
