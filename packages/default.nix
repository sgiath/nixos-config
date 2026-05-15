pkgs: {
  bird = pkgs.callPackage ./bird { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  eve-flipper = pkgs.callPackage ./eve-flipper { };
  fusion = pkgs.callPackage ./fusion { };
  gogcli = pkgs.callPackage ./gogcli { };
  kimi-webbridge = pkgs.callPackage ./kimi-webbridge { };
  n8n = pkgs.callPackage ./n8n { };
  nak = pkgs.callPackage ./nak { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  openclaw = pkgs.callPackage ./openclaw { };
  plannotator = pkgs.callPackage ./plannotator { };
  qmd = pkgs.callPackage ./qmd { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code = pkgs.callPackage ./t3code { };
}
