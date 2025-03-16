{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.email_client = {
    enable = lib.mkEnableOption "Email Client";
  };

  config = lib.mkIf config.sgiath.email_client.enable {
    home = {
      packages = with pkgs; [
        claws-mail

        protonmail-bridge-gui
        protonmail-desktop
      ];

      file.".signature".text = ''
        Filip Vavera

        https://sgiath.dev
        GPG: 0x70F9C7DE34CB3BC8

        Why is HTML email a security nightmare? See https://useplaintext.email/
      '';
    };

    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgs.protonmail-desktop}/bin/proton-mail"
    ];

    services.pass-secret-service.enable = true;
  };
}
