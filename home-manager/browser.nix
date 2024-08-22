{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.browser = {
    enable = lib.mkEnableOption "browser";
  };

  config = lib.mkIf config.sgiath.browser.enable {
    programs = {
      browserpass = {
        enable = true;
        browsers = [
          "chromium"
          "firefox"
        ];
      };

      chromium = {
        enable = true;
        package = pkgs.ungoogled-chromium;
        extensions = [
          # dark reader
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }
          # proton pass
          { id = "ghmbeldphafepmbegfdlkpapadhbakde"; }
          # social focus
          { id = "abocjojdmemdpiffeadpdnicnlhcndcg"; }
          # uBlock origin
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }
        ];
        commandLineArgs = [
          "--enable-features=WebUIDarkMode,DisableQRGenerator"

          "--force-dark-mode"

          "--vulkan"
          "--use-vulkan"
          "--webview-enable-vulkan"

          "--ignore-gpu-blocklist"
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

      firefox = {
        enable = true;
      };

      librewolf = {
        enable = true;
      };

      qutebrowser = {
        enable = true;
      };
    };
  };
}
