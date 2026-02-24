pkgs: {
  bird = pkgs.callPackage ./bird { };
  claude-code-acp = pkgs.callPackage ./claude-code-acp { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  gogcli = pkgs.callPackage ./gogcli { };
  n8n = pkgs.callPackage ./n8n { };
  nak = pkgs.callPackage ./nak { };
  openclaw = pkgs.callPackage ./openclaw { };
  relay-tester = pkgs.callPackage ./relay-tester { };
}
