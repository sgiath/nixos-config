pkgs: {
  bird = pkgs.callPackage ./bird { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  gogcli = pkgs.callPackage ./gogcli { };
  n8n = pkgs.callPackage ./n8n { };
  nak = pkgs.callPackage ./nak { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  openclaw = pkgs.callPackage ./openclaw { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code = pkgs.callPackage ./t3code { };
}
