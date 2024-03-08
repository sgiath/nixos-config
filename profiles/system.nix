{ config, lib, pkgs, systemSettings, userSettings, ... }:

{
  # VirtualBox
  # virtualisation.virtualbox.guest.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod;
    extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl = {
      "vm.max_map_count" = 16777216;
      "fs.file-max" = 524288;
    };
  };

  networking = {
    hostName = systemSettings.hostname;
    networkmanager.enable = true;
    firewall.enable = false;
  };

  # Set your time zone.
  time.timeZone = systemSettings.timezone;
  services.timesyncd.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = systemSettings.locale;

  console = {
    font = "Lat2-Terminus16";
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
        extraGroups = [ "networkmanager" "wheel" ];
      };
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment = {
    shells = with pkgs; [ bash zsh ];
    systemPackages = with pkgs; [ neovim wget git ];
  };

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    zsh.enable = true;
    dconf.enable = true;
  };

  # do not require password for sudo
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "23.11";

  # flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
