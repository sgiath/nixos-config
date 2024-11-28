{
  inputs = {
    nixpkgs-master.url = "nixpkgs/master";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-24.11";
    nixpkgs-proton.url = "github:daniel-fahey/nixpkgs/protonmail-bridge-gui-qt68support";

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
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      rev = "v0.45.2";
      # rev = "1fb720b62aeb474873ba43426ddc53afde1e6cdd";
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

    foundryvtt = {
      url = "github:reckenrode/nix-foundryvtt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    conduwuit = {
      url = "github:girlbossceo/conduwuit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # stylix
    base16 = {
      # url = "github:SenchoPens/base16.nix";
      url = "github:Noodlez1232/base16.nix/slugify-fix";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.base16.follows = "base16";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        allowBroken = false;
        permittedInsecurePackages = [
          "jitsi-meet-1.0.8043"
          "cinny-4.2.3"
          "cinny-unwrapped-4.2.3"
          "olm-3.2.16"
        ];
      };

      overlays = with inputs; [
        nixpkgs-wayland.overlay
      ];

      systems.modules.nixos = with inputs; [
        stylix.nixosModules.stylix
        disko.nixosModules.disko
        nix-bitcoin.nixosModules.default
        simple-nixos-mailserver.nixosModules.mailserver
        foundryvtt.nixosModules.foundryvtt
      ];

      # homes.modules = with inputs; [
      #   stylix.homeManagerModules.stylix
      # ];
    };
}
