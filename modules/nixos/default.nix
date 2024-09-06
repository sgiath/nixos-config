{
  config,
  lib,
  inputs,
  outputs,
  pkgs,
  userSettings,
  ...
}:
{
  imports = [
    # always enabled
    ./bitcoin.nix
    ./boot.nix
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
    };

    users = {
      defaultUserShell = pkgs.zsh;
      users.${userSettings.username} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPassword = userSettings.hashedPassword;
      };
    };
  };
}
