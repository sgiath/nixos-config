{ config, lib, ... }:

{
  options.sgiath.printing = {
    enable = lib.mkEnableOption "printing";
  };

  config = lib.mkIf config.sgiath.printing.enable {
    services = {
      printing.enable = true;

      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };
  };
}
