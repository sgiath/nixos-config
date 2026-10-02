pkgs: {
  agent-orchestrator = pkgs.callPackage ./agent-orchestrator { };
  bird = pkgs.callPackage ./bird { };
  blender-mcp = pkgs.callPackage ./blender-mcp { };
  burn-iso = pkgs.callPackage ./burn-iso { };
  clawpatch = pkgs.callPackage ./clawpatch { };
  clear-cache = pkgs.callPackage ./clear-cache { };
  delta = pkgs.callPackage ./delta { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  fix-images = pkgs.callPackage ./fix-images { };
  herdr-web-ui = pkgs.callPackage ./herdr-web-ui { };
  katrain = pkgs.callPackage ./katrain { };
  live-install = pkgs.callPackage ./live-install { };
  nak = pkgs.callPackage ./nak { };
  openclaw-desktop = pkgs.callPackage ./openclaw-desktop { };
  quickshell = pkgs.callPackage ./quickshell { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  update = pkgs.callPackage ./update { };
  whiteboard = pkgs.callPackage ./whiteboard { };
  xurl = pkgs.callPackage ./xurl { };
}
