{
  inputs = {
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

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

    # https://github.com/hyprwm/Hyprland/releases/latest
    hyprland.url = "github:hyprwm/Hyprland/v0.55.2";
    # hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
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

    # https://github.com/anomalyco/opencode/releases/latest
    opencode = {
      url = "github:anomalyco/opencode/v1.15.4";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/NousResearch/hermes-agent/releases/latest
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.5.16";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niamh = {
    #   url = "path:/home/sgiath/develop/sgiath/niamh";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # bird-src = {
    #   url = "path:/home/sgiath/develop/sgiath/bird";
    #   flake = false;
    # };

    # whisper-dict = {
    #   url = "github:sgiath/whisper-dict";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # https://github.com/max-sixty/worktrunk/releases/latest
    worktrunk = {
      url = "github:max-sixty/worktrunk/v0.53.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/gastownhall/beads/releases/latest
    beads.url = "github:gastownhall/beads/v1.0.4";
    # https://github.com/gastownhall/gastown/releases/latest
    gas-town.url = "github:gastownhall/gastown/v1.1.0";

    # https://github.com/MrLesk/Backlog.md/releases/latest
    backlog-md.url = "github:MrLesk/Backlog.md/v1.45.1";

    comfyui.url = "github:utensils/comfyui-nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://hyprland.cachix.org"
      "https://zed.cachix.org"
      "https://noctalia.cachix.org"
      "https://comfyui.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
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
        permittedInsecurePackages = [
          # "jitsi-meet-1.0.8043"
          # "electron-36.9.5"
          # "olm-3.2.16"
        ];
      };

      overlays = with inputs; [
        hyprland.overlays.default
        nix-minecraft.overlay
        noctalia.overlays.default
        hermes-agent.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        hyprland.nixosModules.default
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        stylix.nixosModules.stylix
        hermes-agent.nixosModules.default
        foundryvtt.nixosModules.foundryvtt
        nix-minecraft.nixosModules.minecraft-servers
        nix-gaming.nixosModules.pipewireLowLatency
        comfyui.nixosModules.default
      ];

      homes.modules = with inputs; [
        hyprland.homeManagerModules.default
        noctalia.homeModules.default
        sops-nix.homeManagerModules.sops
        nix-index-database.homeModules.nix-index
        # whisper-dict.homeManagerModules.default
        # niamh.homeManagerModules.default
      ];
    };
}
