{
  config,
  lib,
  inputs,
  outputs,
  pkgs,
  secrets,
  ...
}:
{
  imports = [
    # always enabled
    ./bitcoin.nix
    ./boot.nix
    ./mailserver.nix
    ./mounting_usb.nix
    ./networking.nix
    ./optimizations.nix
    ./security.nix
    ./stylix.nix
    ./time_lang.nix
    ./udev.nix

    # enable switch
    ./amd-gpu.nix
    ./audio.nix
    ./bluetooth.nix
    ./docker.nix
    ./graphics.nix
    ./nvidia-gpu.nix
    ./printing.nix
    ./razer.nix
    ./wayland.nix

    ./crazyegg
    # ./server
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    system.stateVersion = "23.11";

    nixpkgs = {
      overlays = [
        outputs.overlays.additions
        outputs.overlays.modifications
        outputs.overlays.stable-packages
        outputs.overlays.master-packages
        inputs.nur.overlay
        inputs.nixpkgs-wayland.overlay
      ];

      config = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
    };

    nix = {
      package = pkgs.nixVersions.latest;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://nixpkgs-wayland.cachix.org"
          "https://hyprland.cachix.org"
        ];
      };
      channel.enable = false;
      optimise.automatic = true;
      gc = {
        automatic = true;
        dates = "16:00";
        persistent = true;
      };
    };

    users.defaultUserShell = pkgs.zsh;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs outputs secrets;
      };
      sharedModules = [
        outputs.homeManagerModules
      ];
    };
  };
}
