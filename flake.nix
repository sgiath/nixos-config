{
  inputs = {
    nixpkgs-master.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-24.05";
    nur.url = "github:nix-community/NUR";

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
    { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;

      system = "x86_64-linux";

      hosts = [
        # desktop
        "ceres"
        # server
        "vesta"
        # notebook
        "pallas"
      ];

      userSettings = {
        users.users.sgiath = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3"
          ];
        };
      };

      pkgs = import nixpkgs { inherit system; };
      secrets = builtins.fromJSON (builtins.readFile ./secrets.json);
    in
    {
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      formatter.${system} = pkgs.nixfmt-rfc-style;

      overlays = import ./overlays { inherit inputs system; };
      packages.${system} = import ./pkgs pkgs;
      lib = import ./lib { inherit (nixpkgs) lib; };

      devShells = import ./shell.nix { inherit pkgs; };

      nixosConfigurations =
        nixpkgs.lib.genAttrs hosts (
          host:
          nixpkgs.lib.nixosSystem {
            system = pkgs.system;
            specialArgs = {
              inherit inputs outputs secrets;
            };
            modules = [
              # 3rd party modules
              inputs.home-manager.nixosModules.home-manager
              inputs.nur.nixosModules.nur
              inputs.disko.nixosModules.disko
              inputs.nix-bitcoin.nixosModules.default
              inputs.simple-nixos-mailserver.nixosModules.mailserver
              # local modules
              outputs.nixosModules
              # user settings
              userSettings

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
