{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-23.11";
    # nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-bitcoin = {
      url = "github:fort-nix/nix-bitcoin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-citizen = {
      url = "github:LovingMelody/nix-citizen";
      inputs.nix-gaming.follows = "nix-gaming";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      hyprland,
      home-manager,
      ...
    }@inputs:
    let
      # ---- USER SETTINGS ---- #
      userSettings = {
        username = "sgiath";
        email = "sgiath@sgiath.dev";
      };

      hosts = [
        "ceres"
        "vesta"
        "pallas"
      ];

      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      nixosConfigurations =
        nixpkgs.lib.genAttrs hosts (
          host:
          nixpkgs.lib.nixosSystem {
            system = pkgs.system;
            specialArgs = {
              inherit inputs;
              inherit userSettings;
            };
            modules = [
              hyprland.nixosModules.default
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit inputs;
                    inherit userSettings;
                  };

                  users.${userSettings.username} = import (./. + "/hosts/${host}/home.nix");
                };
              }

              (./. + "/hosts/${host}/system.nix")
            ];
          }
        )
        // {
          installIso = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs;
            };
            modules = [ ./hosts/isoimage/system.nix ];
          };
        };
    };
}
