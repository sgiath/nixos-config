{
  config,
  lib,
  outputs,
  pkgs,
  userSettings,
  ...
}:
{
  imports = [
    # always enabled
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
    ./gaming.nix
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
      ];

      config = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
    };

    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
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
