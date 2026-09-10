{
  config,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      texliveMedium
      # lmstudio
      # davinci-resolve-studio
      whisper-cpp-vulkan
    ];

    sessionVariables = {
      # cd ~/.local/share/whisper-cpp && whisper-cpp-download-ggml-model large-v3-turbo
      WHISPER_MODEL = "${config.xdg.dataHome}/whisper-cpp/ggml-large-v3-turbo.bin";
    };
  };

  sgiath.work = {
    crazyegg.enable = true;
    remote.enable = true;
  };

  sgiath.desktop = {
    # Login default stays Noctalia; `desktop-shell sgiath` switches at runtime.
    quickshell = {
      live = true;
      # DP-2 is Slack's, edge to edge.
      ignoredOutputs = [ "DP-2" ];
    };
    wallpaper = ../../../modules/home/desktop/wallpapers/waifu-lollipop.mp4;
  };

  services = {
    cli-proxy-api.enable = true;
    system-failure-watcher.enable = true;
    t3code.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
