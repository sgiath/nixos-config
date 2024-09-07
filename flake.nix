{

  description = "Sgiath system config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "nixpkgs/master";
    nixpkgs-stable.url = "nixpkgs/nixos-24.05";
    nur.url = "github:nix-community/NUR";

    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      # rev = "4af9410dc2d0e241276a0797d3f3d276310d956e";
      submodules = true;
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

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      formatter = pkgs.nixfmt-rfc-style;

      overlays = import ./overlays { inherit inputs system; };
      packages = import ./pkgs pkgs;
      lib = import ./lib { inherit (nixpkgs) lib; };

      devShells = import ./shell.nix { inherit pkgs; };

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
              inputs.nur.nixosModules.nur
              inputs.disko.nixosModules.disko
              inputs.nix-bitcoin.nixosModules.default
              inputs.simple-nixos-mailserver.nixosModules.mailserver
              outputs.nixosModules

              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit inputs outputs;
                    inherit userSettings secrets;
                  };
                  sharedModules = [
                    outputs.homeManagerModules
                  ];

                  users.${userSettings.username} = import (./. + "/hosts/${host}/home.nix");
                };
              }

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
