{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    services = {
      printing.enable = true;

      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };

    # Canon MAXIFY MB2300 on the home LAN; BJNP broadcast discovery does not find it.
    hardware.sane = {
      enable = true;
      extraBackends = [ (pkgs.writeTextDir "etc/sane.d/pixma.conf" "bjnp://192.168.1.221\n") ];
    };

    users.users.sgiath.extraGroups = [
      "scanner"
      "lp"
    ];
  };
}
