pkgs: {
  bird = pkgs.callPackage ./bird { };
  claude-agent-acp = pkgs.callPackage ./claude-agent-acp { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  gogcli = pkgs.callPackage ./gogcli { };
  n8n = pkgs.callPackage ./n8n { };
  nak = pkgs.callPackage ./nak { };
  openclaw = pkgs.callPackage ./openclaw { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code = pkgs.callPackage ./t3code { };
}
