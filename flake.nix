{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
    NvChad.url = "github:NvChad/nix";

    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs = { self, nixpkgs, home-manager, NvChad, stylix, ... }@inputs:
    let
      # ---- SYSTEM SETTINGS ---- #
      systemSettings = {
        system = "x86_64-linux";
        timezone = "UTC";
        locale = "en_US.UTF-8";
      };

      # ---- USER SETTINGS ---- #
      userSettings = {
        username = "sgiath";
        email = "sgiath@sgiath.dev";
        dotfilesDir = "/home/sgiath/.dotfiles";
      };

      pkgs = import nixpkgs {
        system = systemSettings.system;
        config.allowUnfree = true;
      };
    in {

    # system
    nixosConfigurations = {
      # desktop
      ceres = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        specialArgs = inputs // {
          inherit systemSettings;
          inherit userSettings;
        };
        modules = [
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = inputs // {
                inherit systemSettings;
                inherit userSettings;
              };

              users.${userSettings.username} = import ./profiles/ceres/home.nix;
            };
          }

          ./profiles/ceres/system.nix
        ];
      };

      # server
      vesta = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        specialArgs = inputs // {
          inherit systemSettings;
          inherit userSettings;
        };
        modules = [
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = inputs // {
                inherit systemSettings;
                inherit userSettings;
              };

              users.${userSettings.username} = import ./profiles/vesta/home.nix;
            };
          }

          ./profiles/vesta/system.nix
        ];
      };

      # notebook
      pallas = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        specialArgs = inputs // {
          inherit systemSettings;
          inherit userSettings;
        };
        modules = [
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = inputs // {
                inherit systemSettings;
                inherit userSettings;
              };

              users.${userSettings.username} = import ./profiles/pallas/home.nix;
            };
          }

          ./profiles/pallas/system.nix
        ];
      };
    };
  };
}
