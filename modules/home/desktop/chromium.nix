{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.chromium.enable {
    programs.chromium = {
      package = pkgs.ungoogled-chromium;
      dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
      nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ];
      commandLineArgs = [
        "--password-store=basic"
        "--ozone-platform-hint=wayland"
        "--gtk-version=4"
        "--enable-wayland-ime"
        "--disable-features=ExtensionManifestV2Unsupported"

        "--enable-features=WebUIDarkMode"
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
      ];
    };

    # One launcher per JetKVM in the Nebula peers table. ungoogled-chromium
    # hides every local address from WebRTC, so the KVM's video connection
    # never forms; only this separate profile exposes them, the main profile
    # keeps the private default.
    xdg.desktopEntries = lib.mapAttrs' (
      name: _:
      lib.nameValuePair name {
        name = "KVM ${lib.removePrefix "kvm-" name}";
        exec = lib.concatStringsSep " " [
          (lib.getExe config.programs.chromium.finalPackage)
          "--user-data-dir=${config.xdg.dataHome}/jetkvm-browser"
          "--webrtc-ip-handling-policy=default_public_and_private_interfaces"
          "--app=http://${name}.${osConfig.sgiath.nebula.domain}/"
        ];
        icon = "computer";
        categories = [ "Network" ];
      }
    ) (lib.filterAttrs (name: _: lib.hasPrefix "kvm-" name) osConfig.sgiath.nebula.peers);

    # open PDF in Chromium
    home.activation.setChromiumAsPdfHandler = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe' pkgs.xdg-utils "xdg-mime"} default chromium-browser.desktop application/pdf
    '';

    # workspace 3 is dedicated to the personal Chromium
    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = "chromium-browser";
        workspace = "2 silent";
      }
    ];
  };
}
