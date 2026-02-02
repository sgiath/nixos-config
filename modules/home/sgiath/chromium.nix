{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.chromium.enable {
    programs.chromium = {
      # package = pkgs.ungoogled-chromium;
      dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
      commandLineArgs = [
        "--password-store=gnome-libsecret"
        "--ozone-platform-hint=wayland"
        "--gtk-version=4"
        "--enable-features=TouchpadOverscrollHistoryNavigation"
        "--enable-wayland-ime"
        "--disable-features=ExtensionManifestV2Unsupported"

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

    wayland.windowManager.hyprland.settings.windowrule = [
      "match:class chromium-browser, workspace 2 silent"
    ];
  };
}
