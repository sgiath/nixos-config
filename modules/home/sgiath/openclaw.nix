{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.openclaw.enable {
    programs.openclaw = {
      documents = ./openclaw;
      toolNames = [ ];

      # firstParty = {
      #   summarize.enable = true; # Summarize web pages, PDFs, videos
      #   peekaboo.enable = true; # Take screenshots
      #   oracle.enable = false; # Web search
      #   poltergeist.enable = false; # Control your macOS UI
      #   sag.enable = false; # Text-to-speech
      #   camsnap.enable = false; # Camera snapshots
      #   gogcli.enable = false; # Google Calendar
      #   bird.enable = false; # Twitter/X
      #   sonoscli.enable = false; # Sonos control
      #   imsg.enable = false; # iMessage
      # };

      config = {
        channels.telegram = {
          tokenFile = "/home/sgiath/.telegram-clawdbot";
          allowFrom = [ 5162798212 ];
        };
      };

      instances.default = {
        enable = true;
        launchd.enable = true;
        # package = pkgs.openclawPackages.withTools { ... }.openclaw;

        stateDir = "/home/sgiath/.openclaw";
        workspaceDir = "/home/sgiath/.openclaw/workspace";
      };
    };
  };
}
