{
  config,
  pkgs,
  namespace,
  ...
}:
{
  home = {
    packages = with pkgs; [
      texliveMedium
      # lmstudio
      # davinci-resolve-studio
      whisper-cpp-vulkan
      pkgs.${namespace}.katrain
    ];

    sessionVariables = {
      # cd ~/.local/share/whisper-cpp && whisper-cpp-download-ggml-model large-v3-turbo
      WHISPER_MODEL = "${config.xdg.dataHome}/whisper-cpp/ggml-large-v3-turbo.bin";
    };
  };

  sgiath.programs.blender.enable = false;

  sgiath.work = {
    crazyegg.enable = true;
    remote.enable = true;
  };

  sgiath.desktop = {
    # Login default stays Noctalia; `desktop-shell sgiath` switches at runtime.
    quickshell = {
      live = true;
      # DP-1 is the main screen; DP-2 is Slack's, edge to edge.
      mainOutput = "DP-1";
      ignoredOutputs = [ "DP-2" ];
      pinned = [
        "chromium-browser"
        "google-chrome"
        "firefox"
        "dev.zed.Zed"
      ];
    };
    wallpaper = ../../../modules/home/desktop/wallpapers/massier.jpg;
  };

  services = {
    davinci-resolve-mcp.enable = false;
    herdr-server.enable = true;
    # Settings changed in its UI (http://127.0.0.1:8787) override these.
    auto-review = {
      enable = true;
      repos =
        let
          dev = "${config.home.homeDirectory}/develop";
          # Remote work goes through the Remote accounts behind the proxy.
          reviewer = {
            provider = "opencode";
            model = "cliproxy/remote/claude-opus-5-5";
            effort = "high";
          };
        in
        {
          "gitlab:remote-com/neo-payroll/neo" = {
            checkout = "${dev}/remote/neo-payroll/neo";
            t3Project = "cc302d40-6268-4d27-8a59-47d572eedc9b";
            context = builtins.readFile ./auto-review/neo.md;
            inherit reviewer;
          };
          "gitlab:remote-com/employ-starbase/tiger" = {
            checkout = "${dev}/remote/tiger";
            t3Project = "mcp:d4ad1cbf-7018-4e8e-918a-9130573c335a";
            context = builtins.readFile ./auto-review/tiger.md;
            inherit reviewer;
          };
          "gitlab:remote-com/employ-starbase/dragon" = {
            checkout = "${dev}/remote/dragon";
            t3Project = "mcp:7e27a2a0-c09b-4fc5-a9bd-df76ea56f48f";
            context = builtins.readFile ./auto-review/dragon.md;
            inherit reviewer;
          };
          "gitlab:remote-com/neo-payroll/architect" = {
            checkout = "${dev}/remote/neo-payroll/architect";
            t3Project = "3f2dd0df-b80d-4b35-96c6-6bd09c5f3dba";
            context = builtins.readFile ./auto-review/architect.md;
            inherit reviewer;
          };
          "gitlab:remote-com/workbench/remote-vibed-labs" = {
            checkout = "${dev}/remote/remote-vibed-labs";
            t3Project = "mcp:118d46ef-c352-4e26-91ec-e5acdd216ad8";
            context = builtins.readFile ./auto-review/labs.md;
            inherit reviewer;
          };
          "github:CrazyEggInc/ce" = {
            checkout = "${dev}/crazyegg/core_v2";
            t3Project = "d0a53fe2-efca-47c4-82cc-714cd179caf1";
            context = builtins.readFile ./auto-review/ce.md;
          };
        };
    };
    t3code = {
      enable = true;
      channel = "nightly";
      publicUrl = "https://t3-ceres.sgiath.dev";
    };
  };

  stylix = {
    fonts.sizes = {
      applications = 10;
      desktop = 10;
      popups = 10;
      terminal = 10;
    };

    # I want my editor to be a bit bigger
    targets.zed.fonts.override = {
      sizes = {
        applications = 12;
        desktop = 12;
      };
    };
  };
}
