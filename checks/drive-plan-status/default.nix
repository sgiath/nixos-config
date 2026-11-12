# `nix flake check`: drive's plan-status routes a plan to its code repository, state key and T3 project.
{
  lib,
  runCommand,
  python3,
  git,
}:

let
  src = lib.fileset.toSource {
    root = ../..;
    fileset = ../../modules/home/agents/skills/drive/scripts;
  };
in
runCommand "drive-plan-status"
  {
    nativeBuildInputs = [
      python3
      git
    ];
  }
  ''
    export HOME=$TMPDIR
    python3 -I -B -m unittest discover -s ${src}/modules/home/agents/skills/drive/scripts -p 'test_*.py' -v
    touch $out
  ''
