{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath = {
    xamond.enable = lib.mkEnableOption "xamond kernel";
    boot = lib.mkOption {
      default = "uefi";
      example = "legacy";
      type = lib.types.enum [
        "uefi"
        "legacy"
      ];
    };
  };

  config = lib.mkIf config.sgiath.enable {
    boot = {
      kernelPackages =
        if config.sgiath.xamond.enable then pkgs.linuxPackages_xanmod_latest else pkgs.linuxPackages_latest;

      loader =
        if config.sgiath.boot == "uefi" then
          {
            systemd-boot = {
              enable = true;
              configurationLimit = 2;
            };
            efi.canTouchEfiVariables = true;
          }
        else
          {
            grub = {
              enable = true;
              configurationLimit = 10;
            };
          };
    };

    console = {
      font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
      earlySetup = true;
      useXkbConfig = true;
    };

    environment = {
      shells = with pkgs; [
        bash
        zsh
        fish
        nushell
      ];
      systemPackages = with pkgs; [
        neovim
        git
        fish
        nushell
      ];
    };

    programs = {
      zsh.enable = true;
      dconf.enable = true;
    };
  };
}
