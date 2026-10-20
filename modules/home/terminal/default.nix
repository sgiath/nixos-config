{ lib, ... }:
{
  imports = [
    ./role.nix
    ./git.nix
    ./gpg.nix
    ./herdr.nix
    ./ssh.nix
    ./starship.nix
    ./worktrunk.nix
    ./zsh.nix
  ];

  options.sgiath.roles.terminal.enable = lib.mkEnableOption "terminal role";
}
