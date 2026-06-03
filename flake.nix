{
  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-ksa.url = "github:Leha44581/nixpkgs/ksa";

    home-manager.url = "github:nix-community/home-manager";

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

    hyprland.url = "github:hyprwm/Hyprland/v0.55.2";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/v4.7.7";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # https://forgejo.ellis.link/continuwuation/continuwuity/releases
    continuwuity = {
      url = "git+https://forgejo.ellis.link/continuwuation/continuwuity?rev=051449118911b03960d5d09f630d7d2959c8330c";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    worktrunk = {
      url = "github:max-sixty/worktrunk/v0.56.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bird-src = {
      url = "path:/home/sgiath/develop/sgiath/bird";
      flake = false;
    };

    voxtype.url = "github:peteonrails/voxtype/v0.7.5";
    comfyui.url = "github:utensils/comfyui-nix/v0.18.2";

    # LLM tools

    llm-agents.url = "github:numtide/llm-agents.nix";

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.5.29.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    backlog-md = {
      url = "github:MrLesk/Backlog.md/v1.45.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://hyprland.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://zed.cachix.org"
      "https://noctalia.cachix.org"
      "https://comfyui.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    ];
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
        rocmSupport = true;
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };

      overlays = with inputs; [
        hyprland.overlays.default
        noctalia.overlays.default
        hermes-agent.overlays.default
        llm-agents.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        hyprland.nixosModules.default
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        stylix.nixosModules.stylix
        hermes-agent.nixosModules.default
        foundryvtt.nixosModules.foundryvtt
        nix-gaming.nixosModules.pipewireLowLatency
        nix-gaming.nixosModules.platformOptimizations
        nix-gaming.nixosModules.wine
        comfyui.nixosModules.default
      ];

      homes.modules = with inputs; [
        hyprland.homeManagerModules.default
        noctalia.homeModules.default
        sops-nix.homeManagerModules.sops
        nix-index-database.homeModules.nix-index
        voxtype.homeManagerModules.default
      ];
    };
}
