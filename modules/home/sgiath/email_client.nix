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

        proton-vpn
        proton-pass
        proton-pass-cli
        proton-authenticator
      ];

      file.".signature".text = ''
        Filip Vavera
        https://sgiath.dev

        GPG fingerprint:
        B166 3624 D093 688E D5C3 296B 70F9 C7DE 34CB 3BC8

        Why is HTML email a security nightmare? See https://useplaintext.email/
      '';
    };

    wayland.windowManager.hyprland.settings = {
      exec-once = [ "${lib.getExe pkgs.protonmail-desktop}" ];
      windowrule = [
        "match:class claws-mail, workspace 9 silent, no_initial_focus on"
        "match:title Proton Mail, workspace 9 silent, no_initial_focus on"
      ];
    };

    services.protonmail-bridge.enable = false;
  };
}
