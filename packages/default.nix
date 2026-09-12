pkgs: {
  bird = pkgs.callPackage ./bird { };
  burn-iso = pkgs.callPackage ./burn-iso { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  clear-cache = pkgs.callPackage ./clear-cache { };
  delta = pkgs.callPackage ./delta { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  fix-images = pkgs.callPackage ./fix-images { };
  grok-bot = pkgs.callPackage ./grok-bot { };
  katrain = pkgs.callPackage ./katrain { };
  live-install = pkgs.callPackage ./live-install { };
  nak = pkgs.callPackage ./nak { };
  omnisearch = pkgs.callPackage ./omnisearch { };
  quickshell = pkgs.callPackage ./quickshell { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  update = pkgs.callPackage ./update { };
  xurl = pkgs.callPackage ./xurl { };
}
