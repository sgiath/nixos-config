{
  config,
  pkgs,
  userSettings,
  ...
}:

{
  imports = [
    ./amd-gpu.nix
    ./nvidia-gpu.nix
    ./bluetooth.nix
    ./gaming.nix
    ./stylix.nix
    ./sound.nix
    ./wayland.nix
    ./printing.nix
    ./networking.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "vm.max_map_count" = 16777216;
      "fs.file-max" = 524288;
    };
  };

  # Set your time zone.
  time.timeZone = "UTC";
  services.timesyncd.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    earlySetup = true;
    useXkbConfig = true;
  };

  # OpenSSH
  services.openssh.enable = true;

  # Power settings
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 80;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      ${userSettings.username} = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "openrazer"
          "docker"
          "dialout"
        ];
        hashedPassword = "$y$j9T$EBb/Mjo7nNHfmtbiP1GST0$CctYXT62gX0cMDHzRzYxlix43xC3U6kzSDNvyqZOcj4";
      };
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ ];
  };

  environment = {
    shells = with pkgs; [
      bash
      zsh
    ];
    systemPackages = with pkgs; [
      neovim
      git
    ];
    sessionVariables = {
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      FLAKE = "/home/sgiath/.dotfiles";
    };
  };

  programs = {
    mtr.enable = true;
    zsh.enable = true;
    dconf.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
    nix-ld.enable = true;
  };

  # mounting USBs
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    dbus.packages = [ pkgs.gcr ];

    livebook = {
      enableUserService = true;
    };
  };

  # do not require password for sudo
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    doas = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
  environment.shellAliases.sudo = "doas";

  system.stateVersion = "23.11";

  # Nix config
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # package = pkgs.nixVersions.nix_2_23;
    gc = {
      automatic = false;
      dates = "daily";
    };
  };
}
