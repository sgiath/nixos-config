{
  inputs,
  pkgs,
  namespace,
  ...
}:
final: prev:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = false;
      allowUnfree = true;
    };
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = prev.stdenv.hostPlatform.system;
    config = {
      cudaSupport = false;
      rocmSupport = false;
      allowUnfree = true;
    };
  };
in
{
  # my custom derivations
  bdui = pkgs.${namespace}.bdui;
  claude-code-acp = pkgs.${namespace}.claude-code-acp;
  dnd5etools = pkgs.${namespace}.dnd5etools;
  gastown = pkgs.${namespace}.gastown;
  lazybeads = pkgs.${namespace}.lazybeads;
  n8n = pkgs.${namespace}.n8n;
  ntm = pkgs.${namespace}.ntm;
  openspec = pkgs.${namespace}.openspec;
}
