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
    home.packages = with pkgs; [
      ungoogled-chromium
      firefox
    ];

    xdg.configFile."chromium-flags.conf".text = ''
      --enable-features=WebUIDarkMode,DisableQRGenerator

      --force-dark-mode

      --vulkan
      --use-vulkan
      --webview-enable-vulkan

      --ignore-gpu-blocklist
      --enable-gpu-rasterization
      --enable-zero-copy

      --disable-search-engine-collection
      --keep-old-history
      --max-connections-per-host=15
      --popups-to-tabs
      --close-window-with-last-tab=never

      --fingerprinting-canvas-image-data-noise
      --fingerprinting-canvas-measuretext-noise
      --fingerprinting-client-rects-noise

      --ssl-key-log-file=/home/sgiath/.ssl_keylog
    '';
  };
}
