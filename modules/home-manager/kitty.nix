{ config, lib, ... }:

{
  options.sgiath.kitty = {
    enable = lib.mkEnableOption "kitty";
  };

  config = lib.mkIf config.sgiath.kitty.enable {
    programs.kitty.enable = true;
  };
}
