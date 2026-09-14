{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    boot = {
      loader =
        if config.sgiath.hardware.boot == "uefi" then
          {
            systemd-boot = {
              enable = true;
              configurationLimit = 3;
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
