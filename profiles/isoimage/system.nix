{ pkgs, modulesPath, systemSettings, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.hostPlatform = systemSettings.system;

  environment.systemPackages = with pkgs; [
    neovim
    parted
    git
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
