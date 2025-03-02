{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.programs.chromium.enable {
    home.packages = [
      pkgs.tor-browser
      pkgs.zen-browser
    ];

    programs.chromium = {
      package = pkgs.ungoogled-chromium;
      extensions = [
        # dark reader
        { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }
        # proton pass
        { id = "ghmbeldphafepmbegfdlkpapadhbakde"; }
        # social focus
        { id = "abocjojdmemdpiffeadpdnicnlhcndcg"; }
      ];
      dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
      commandLineArgs = [
        "--enable-features=WebUIDarkMode"
        # "--enable-features=Vulkan"
        # "--enable-features=VaapiVideoEncoder"
        # "--enable-features=VaapiVideoDecoder"

        # "--enable-unsafe-webgpu"
        # "--ignore-gpu-blocklist"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"

        "--disable-search-engine-collection"
        "--keep-old-history"
        "--max-connections-per-host=15"
        "--popups-to-tabs"
        "--close-window-with-last-tab=never"

        "--fingerprinting-canvas-image-data-noise"
        "--fingerprinting-canvas-measuretext-noise"
        "--fingerprinting-client-rects-noise"

        "--ssl-key-log-file=/home/sgiath/.ssl_keylog"
      ];
    };
  };
}
