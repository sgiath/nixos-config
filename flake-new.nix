{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # nixpkgs.url = "nixpkgs/master";
    nixpkgs-stable.url = "nixpkgs/nixos-24.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-flake.url = "github:srid/nixos-flake";

    nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "utils";
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
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
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
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.nixos-flake.flakeModule ];

      flake =
        let
          userSettings.username = "sgiath";
          secrets = builtins.fromJSON (builtins.readFile ./secrets.json);
        in
        {
          nixosConfigurations = {
            ceres = self.nixos-flake.lib.mkLinuxSystem {
              nixpkgs.hostPlatform = "x86_64-linux";
              imports = [
                ./hosts/ceres/system.nix

                self.nixosModules.home-manager
                {
                  home-manager.users.${userSettings.username} = import ./hosts/ceres/home.nix {
                    inherit userSettings secrets;
                  };
                }
              ];
            };
          };
        };

      perSystem =
        { pkgs, self', ... }:
        {
          packages.default = self'.packages.activate;
          devShells.default = pkgs.mkShell {
            buildInputs = [ pkgs.nixpkgs-fmt ];
          };
          formatter = pkgs.nixpkgs-fmt;
        };
    };
}
