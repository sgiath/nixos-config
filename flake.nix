{
  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
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

    flake-utils-plus-fixed.url = "path:./vendor/flake-utils-plus-fixed";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.flake-utils-plus.follows = "flake-utils-plus-fixed";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Unpinned from v0.56.2: that release requires glaze 7, but nixpkgs ships glaze 8.
    # Its CMakeLists.txt has `find_package(glaze 7...<8 QUIET)`, which then fails.
    # CMake falls back to FetchContent, and the build sandbox has no network access.
    # Upstream removed the version limit on main in 91f29f2 (2026-08-04), code unchanged.
    # Pin the tag again when a release contains that commit (v0.56.3 or later).

    # pin to v0.56.1
    hyprland.url = "github:hyprwm/Hyprland/v0.56.1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    noctalia.url = "github:noctalia-dev/noctalia/v5.1.0";

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

    prismlauncher = {
      url = "github:PrismLauncher/PrismLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://forgejo.ellis.link/continuwuation/continuwuity/releases
    # v26.8.1
    continuwuity = {
      url = "git+https://forgejo.ellis.link/continuwuation/continuwuity?rev=ab3c05dac6372ddda3d3279c59b998838094a8bc";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    worktrunk = {
      url = "github:max-sixty/worktrunk/v0.77.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    voxtype.url = "github:peteonrails/voxtype/v1.0.1";
    comfyui.url = "github:utensils/comfyui-nix/v0.34.0";

    # LLM tools

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.9.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oh-my-pi = {
      url = "github:can1357/oh-my-pi/v18.1.19";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.9.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:anomalyco/opencode/v1.18.30";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crit = {
      url = "github:tomasz-tomczyk/crit/v0.20.1";
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
      # LLM agents
      "https://cache.numtide.com"
      "https://prismlauncher.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      # LLM agents
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "prismlauncher.cachix.org-1:9/n/FGyABA2jLUVfY+DEp4hKds/rwO+SCOtbOkDzd+c="
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
            title = "sgiath's dotfiles";
          };
        };
      };
    in
    lib.mkFlake {
      outputs-builder =
        channels:
        let
          treefmt = inputs.treefmt-nix.lib.evalModule channels.nixpkgs {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        in
        {
          formatter = treefmt.config.build.wrapper;
        };
      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        hyprland.overlays.default
        hermes-agent.overlays.default
        llm-agents.overlays.shared-nixpkgs
        prismlauncher.overlays.default
        comfyui.overlays.default
        oh-my-pi.overlays.default
        opencode.overlays.default
        herdr.overlays.default
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
        # comfyui.nixosModules.default
        oh-my-pi.nixosModules.default
      ];

      homes.modules = with inputs; [
        hyprland.homeManagerModules.default
        noctalia.homeModules.default
        sops-nix.homeManagerModules.sops
        nix-index-database.homeModules.nix-index
        stylix.homeModules.stylix
        voxtype.homeManagerModules.default
        oh-my-pi.homeManagerModules.default
        worktrunk.homeModules.default
      ];
    };
}
