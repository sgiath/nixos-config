{
  inputs = {
    nixpkgs-master.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-24.11";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland/v0.47.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xdph = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-bitcoin = {
      url = "github:fort-nix/nix-bitcoin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    foundryvtt = {
      url = "github:reckenrode/nix-foundryvtt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    conduwuit = {
      url = "github:girlbossceo/conduwuit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf.url = "github:notashelf/nvf";
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          namespace = "sgiath";
          meta = {
            name = "sgiath";
            title = "Sgiath's flake";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        rocmSupport = false;
        allowUnfree = true;
        permittedInsecurePackages = [
          "jitsi-meet-1.0.8043"
          "cinny-4.2.3"
          "cinny-unwrapped-4.2.3"
          "olm-3.2.16"
        ];
      };

      outputs-builder = channels: {
        packages = {
          conduwuit = inputs.conduwuit.packages.${channels.nixpkgs.system}.all-features;
        };
      };

      overlays = with inputs; [
        nixpkgs-wayland.overlay
        hyprland.overlays.default
        hyprpaper.overlays.default
        xdph.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        stylix.nixosModules.stylix
        disko.nixosModules.disko
        nix-bitcoin.nixosModules.default
        simple-nixos-mailserver.nixosModules.mailserver
        foundryvtt.nixosModules.foundryvtt
      ];

      homes.modules = with inputs; [
        nvf.homeManagerModules.default
      ];
    };
}
