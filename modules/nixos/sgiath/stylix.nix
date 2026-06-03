{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      base16Scheme = ./../../home/sgiath/theme.yaml;
    };
  };
}
