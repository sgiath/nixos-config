{
  config,
  lib,
  inputs,
  pkgs,
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
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    users.users.sgiath = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3"
      ];
    };

    system.stateVersion = "23.11";

    nix = {
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      package = pkgs.nixVersions.latest;
      settings = {
        require-sigs = false;
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
        automatic = false;
        dates = "16:00";
        persistent = true;
      };
    };

    users.defaultUserShell = pkgs.zsh;
  };
}
