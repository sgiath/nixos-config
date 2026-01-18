{
  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager.url = "github:nix-community/home-manager/38e187fd2f9efac197e03be0c25f3ee215974144";

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-flake = {
      url = "github:snowfallorg/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    btc-clients = {
      url = "github:emmanuelrosa/btc-clients-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    foundryvtt = {
      url = "github:reckenrode/nix-foundryvtt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    conduit = {
      url = "gitlab:famedly/conduit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cursor = {
      url = "github:TudorAndrei/cursor-nixos-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/zed-industries/zed/releases/latest
    zed-editor = {
      url = "github:zed-industries/zed/v0.219.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/openai/codex/releases/latest
    codex = {
      url = "github:openai/codex/rust-v0.87.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:sst/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    beads = {
      url = "github:steveyegge/beads/v0.47.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    clawdbot = {
      url = "github:clawdbot/nix-clawdbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          namespace = "sgiath";
          meta = {
            name = "sgiath";
            title = "Sgiath's dotfiles";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        cudaSupport = false;
        rocmSupport = false;
        allowUnfree = true;
        permittedInsecurePackages = [
          "jitsi-meet-1.0.8043"
          "electron-36.9.5"
          # "olm-3.2.16"
        ];
      };

      overlays = with inputs; [
        # zed-editor.overlays.default
        claude-code.overlays.default
        clawdbot.overlays.default
        nix-minecraft.overlay
      ];

      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        stylix.nixosModules.stylix
        foundryvtt.nixosModules.foundryvtt
        nix-minecraft.nixosModules.minecraft-servers
      ];

      homes.modules = with inputs; [
        sops-nix.homeManagerModules.sops
        nix-index-database.homeModules.nix-index
        clawdbot.homeManagerModules.clawdbot
      ];
    };
}
