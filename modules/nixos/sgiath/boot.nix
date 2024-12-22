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
        if config.sgiath.xamond.enable then pkgs.linuxPackages_xanmod_latest else pkgs.linuxPackages_zen;

      loader =
        if config.sgiath.boot == "uefi" then
          {
            systemd-boot = {
              enable = true;
              configurationLimit = 10;
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
      ];
      systemPackages = with pkgs; [
        neovim
        git
      ];
    };

    programs = {
      zsh.enable = true;
      dconf.enable = true;
    };
  };
}
