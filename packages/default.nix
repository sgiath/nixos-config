pkgs: {
  stt = pkgs.callPackage ./stt { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  open-webui = pkgs.callPackage ./open-webui { };
}
