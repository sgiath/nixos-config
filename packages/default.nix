pkgs: {
  bird = pkgs.callPackage ./bird { };
  blender-mcp = pkgs.callPackage ./blender-mcp { };
  burn-iso = pkgs.callPackage ./burn-iso { };
  clear-cache = pkgs.callPackage ./clear-cache { };
  dnd5etools = pkgs.callPackage ./dnd5etools { };
  fix-images = pkgs.callPackage ./fix-images { };
  katrain = pkgs.callPackage ./katrain { };
  live-install = pkgs.callPackage ./live-install { };
  nak = pkgs.callPackage ./nak { };
  openclaw-desktop = pkgs.callPackage ./openclaw-desktop { };
  quickshell = pkgs.callPackage ./quickshell { };
  relay-tester = pkgs.callPackage ./relay-tester { };
  t3code-nightly = pkgs.callPackage ./t3code-nightly { };
  t3code-nightly-desktop = pkgs.callPackage ./t3code-nightly-desktop { };
  t3code-nightly-device-tools = pkgs.callPackage ./t3code-nightly-device-tools { };
  update = pkgs.callPackage ./update { };
  whiteboard = pkgs.callPackage ./whiteboard { };
}
