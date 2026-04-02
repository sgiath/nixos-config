{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.services.hermes-agent.enable {
    services.hermes-agent = {
      user = "sgiath";
      group = "sgiath";
      stateDir = "/home/sgiath/";
      workingDirectory = "/home/sgiath/.hermes/workspace";
      environmentFiles = [ "/home/sgiath/.hermes/env" ];
      addToSystemPackages = true;

      extraPackages = with pkgs; [
        imagemagick
        ffmpeg
        whisper-cpp-vulkan
        yt-dlp
        jq
      ];

      settings = {
        model = {
          default = "claude-opus-4-6";
          provider = "anthropic";
        };

        fallback_model = {
          provider = "openrouter";
          model = "minimax/minimax-m2.7";
        };

        display = {
          personality = "catgirl";
          skin = "charizard";
        };

        toolsets = [ "all" ];

        approvals.mode = "off";

        tts = {
          provider = "openai";
          openai = {
            model = "gpt-4o-mini-tts";
            voice = "maple";
          };
        };

        stt = {
          enabled = true;
          provider = "local";
          local = {
            model = "ggml-large-v3-turbo";
          };
        };
      };
    };
  };
}
