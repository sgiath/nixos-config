{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  pkgs-stable = import inputs.nixpkgs-stable { system = pkgs.system; };
in
{
  options.sgiath.audio = {
    enable = lib.mkEnableOption "audio";
  };

  config = lib.mkIf config.sgiath.audio.enable {
    home.packages = [ pkgs.qpwgraph ];
    services.easyeffects = {
      enable = true;
      package = pkgs-stable.easyeffects;
    };
  };
}
