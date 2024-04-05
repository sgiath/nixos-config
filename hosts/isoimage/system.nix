{ pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs.hostPlatform = pkgs.system;

  environment.systemPackages = with pkgs; [
    neovim
    parted
    git
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
