{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    qpwgraph
  ];

  services.easyeffects.enable = true;
}
