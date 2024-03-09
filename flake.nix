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
        modules = [ ./profiles/ceres/system.nix ];
        specialArgs = {
          inherit systemSettings;
          inherit userSettings;
          hostname = "ceres";

          inherit inputs;
        };
      };

      # server
      vesta = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        modules = [ ./profiles/vesta/system.nix ];
        specialArgs = {
          inherit systemSettings;
          inherit userSettings;
          hostname = "vesta";

          inherit inputs;
        };
      };

      # notebook
      pallas = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        modules = [ ./profiles/pallas/system.nix ];
        specialArgs = {
          inherit systemSettings;
          inherit userSettings;
          hostname = "pallas";

          inherit inputs;
        };
      };
    };

    # home
    homeConfigurations = {
      ${userSettings.username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./profiles/pallas/home.nix
          stylix.homeManagerModules.stylix
          NvChad.homeManagerModules.default
        ];
        extraSpecialArgs = {
          inherit systemSettings;
          inherit userSettings;

          inherit inputs;
        };
      };
    };
  };
}
