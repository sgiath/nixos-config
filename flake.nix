{

  description = "Default flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    stylix.url = "github:danth/stylix";

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-citizen = {
      url = "github:LovingMelody/nix-citizen";
      inputs.nix-gaming.follows = "nix-gaming";
    };
  };

  outputs = { self, nixpkgs, nix-gaming, nix-citizen, home-manager, disko, stylix, ... }@inputs:
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

      pkgs = nixpkgs.legacyPackages.${systemSettings.system};
      pkgs-gaming = nix-gaming.packages.${systemSettings.system};
      pkgs-citizen = nix-citizen.packages.${systemSettings.system};
    in {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts (host: nixpkgs.lib.nixosSystem {
      system = systemSettings.system;
      specialArgs = inputs // {
        inherit systemSettings;
        inherit userSettings;
      };
      modules = [
        disko.nixosModules.disko
        stylix.nixosModules.stylix

        home-manager.nixosModules.home-manager {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = inputs // {
              inherit systemSettings;
              inherit userSettings;
              inherit pkgs-gaming;
              inherit pkgs-citizen;
            };

            users.${userSettings.username} = import ( ./profiles + "/${host}/home.nix" );
          };
        }

        ( ./profiles + "/${host}/system.nix" )
      ];
    }) // {
      installIso = nixpkgs.lib.nixosSystem {
        specialArgs = inputs // { inherit systemSettings; };
        modules = [ ./profiles/isoimage/system.nix ];
      };
    };
  };
}
