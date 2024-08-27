{

  description = "Sgiath system config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # nixpkgs.url = "nixpkgs/master";
    nixpkgs-stable.url = "nixpkgs/nixos-24.05";

    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";

    nur.url = "github:nix-community/NUR";

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
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      system = "x86_64-linux";

      # ---- USER SETTINGS ---- #
      userSettings = {
        username = "sgiath";
        email = "sgiath@sgiath.dev";
        hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3";
      };

      hosts = [
        "ceres"
        "vesta"
        "pallas"
      ];

      pkgs = import nixpkgs { inherit system; };
      secrets = builtins.fromJSON (builtins.readFile ./secrets.json);
    in
    {
      packages = import ./pkgs pkgs;
      formatter = pkgs.nixpkgs-fmt;
      overlays = import ./overlays { inherit inputs; };
      lib = import ./lib { inherit (nixpkgs) lib; };

      nixosModules.default = self.nixosModules.sgiath;
      nixosModules.sgiath.imports = [ ./modules/nixos ];

      homeManagerModules.default = self.homeManagerModules.sgiath;
      homeManagerModules.sgiath.imports = [ ./modules/home-manager ];

      nixosConfigurations =
        nixpkgs.lib.genAttrs hosts (
          host:
          nixpkgs.lib.nixosSystem {
            system = pkgs.system;
            specialArgs = {
              inherit inputs outputs;
              inherit userSettings secrets;
            };
            modules = [
              inputs.disko.nixosModules.disko
              outputs.nixosModules.sgiath

              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit inputs outputs;
                    inherit userSettings secrets;
                  };
                  sharedModules = [ outputs.homeManagerModules.sgiath ];

                  users.${userSettings.username} = import (./. + "/hosts/${host}/home.nix");
                };
              }

              # default config
              ./nixos

              # configuration of the selected system
              (./. + "/hosts/${host}/system.nix")
            ];
          }
        )
        // {
          installIso = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs outputs;
            };
            modules = [ ./hosts/isoimage/system.nix ];
          };
        };
    };
}
