{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";

    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs = { self, nixpkgs, home-manager, stylix, ... }@inputs:
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

      hosts = [ "ceres" "vesta" "pallas" ];

      pkgs = import nixpkgs {
        system = systemSettings.system;
        config.allowUnfree = true;
      };
    in {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts (host: nixpkgs.lib.nixosSystem {
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

            users.${userSettings.username} = import ( ./profiles + "/${host}/home.nix" );
          };
        }

        ( ./profiles + "/${host}/system.nix" )
      ];
    });
  };
}
