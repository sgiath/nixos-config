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
      # excludeTools = [ "summarize" ]; # conflicts with openclaw's own /bin/summarize

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
        package = pkgs.openclaw; # batteries-included

        stateDir = "/home/sgiath/.openclaw";
        workspaceDir = "/home/sgiath/.openclaw/workspace";
      };
    };
  };
}
