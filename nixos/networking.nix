{ config, lib, ... }:

{
  options.sgiath.networking.localDNS = {
    enable = lib.mkEnableOption "local DNS";
  };

  config = {

    networking = {
      resolvconf.enable = false;
      networkmanager = {
        enable = true;
        insertNameservers =
          if config.sgiath.networking.localDNS.enable then
            [
              "192.168.1.2"
              "192.168.1.3"
            ]
          else
            [
              "8.8.8.8"
              "8.8.4.4"
            ];
      };
      firewall.enable = false;
    };
  };
}
