{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  imports = [
    # always enabled
    ./boot.nix
    ./mounting_usb.nix
    ./networking.nix
    ./optimizations.nix
    ./security.nix
    ./stylix.nix
    ./time_lang.nix
    ./udev.nix

    # enable switch
    ./amd-gpu.nix
    ./audio.nix
    ./bluetooth.nix
    ./docker.nix
    ./graphics.nix
    ./nvidia-gpu.nix
    ./ollama.nix
    ./printing.nix
    ./razer.nix
    ./wayland.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    users.users.sgiath = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGJYz3V8IxqdAJw9LLj0RMsdCu4QpgPmItoDoe73w/3"
      ];
    };

    system = {
      stateVersion = "23.11";
      extraDependencies = [
        # inputs.foundryvtt.packages.${system}.foundryvtt_12.src
      ];
    };

    nix = {
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      package = pkgs.nixVersions.latest;
      settings = {
        access-tokens = "github.com=${secrets.github_token}";
        auto-optimise-store = true;
        require-sigs = false;
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cache.thalheim.io-1:R7msbosLEZKrxk/lKxf9BTjOOH7Ax3H0Qj0/6wiHOgc="
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://nixpkgs-wayland.cachix.org"
          "https://hyprland.cachix.org"
          "https://cache.thalheim.io" # sops-nix
        ];
      };
      channel.enable = false;
      optimise.automatic = true;
      gc = {
        automatic = false;
        dates = "08:00";
      };
    };

    users.defaultUserShell = pkgs.zsh;
    environment.sessionVariables = {
      OPENAI_API_KEY = secrets.openai;
      XAI_API_KEY = secrets.xai;
      GEMINI_API_KEY = secrets.gemini;
      ANTHROPIC_API_KEY = secrets.anthropic;
      OPENROUTER_API_KEY = secrets.openrouter;
    };
    programs = {
      nix-ld.enable = true;
    };
  };
}
