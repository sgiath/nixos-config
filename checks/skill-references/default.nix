# `nix flake check`: every skill:// reference and SKILL.md link in the shared
# agent skill catalog and the project catalog in .agents/skills resolves.
{
  lib,
  runCommand,
  python3,
}:

let
  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../modules/home/agents/scripts/check-skill-references.py
      ../../modules/home/agents/skills
      ../../.agents/skills
    ];
  };
in
runCommand "skill-references" { nativeBuildInputs = [ python3 ]; } ''
  python3 ${src}/modules/home/agents/scripts/check-skill-references.py ${src}/.agents/skills
  touch $out
''
