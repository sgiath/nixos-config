{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    home = {
      stateVersion = "23.11";

      packages = with pkgs; [
        pkgs.${namespace}.update
        pkgs.${namespace}.fix-images
        pkgs.${namespace}.fix-video
        pkgs.${namespace}.clear-cache
        pkgs.${namespace}.burn-iso

        # general programs I want to have always available
        imagemagick
        ffmpeg
        zip
        unzip
        p7zip
        wget
        dig
        killall
        inotify-tools
        lshw
        parted
        nix-du
        exfat
      ];
    };

    services = {
      pass-secret-service.enable = true;
    };

    programs = {
      home-manager.enable = true;
      fastfetch.enable = true;

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      password-store = {
        enable = true;
        settings = {
          PASSWORD_STORE_DIR = "${config.xdg.dataHome}/password-store";
        };
        package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
      };
    };

    systemd.user.startServices = "sd-switch";
  };
}
