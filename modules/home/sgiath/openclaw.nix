{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.openclaw.enable {
    programs.openclaw = {
      documents = ./openclaw;

      firstParty = {
        summarize.enable = true; # Summarize web pages, PDFs, videos
        peekaboo.enable = true; # Take screenshots
        oracle.enable = true; # Web search
        poltergeist.enable = false; # Control your macOS UI
        sag.enable = true; # Text-to-speech
        camsnap.enable = true; # Camera snapshots
        gogcli.enable = false; # Google Calendar
        bird.enable = true; # Twitter/X
        sonoscli.enable = false; # Sonos control
        imsg.enable = false; # iMessage
      };

      config = {
        channels.telegram = {
          tokenFile = "/home/sgiath/.telegram-clawdbot";
          allowFrom = [ 5162798212 ];
        };
      };

      instances.default = {
        enable = true;
        launchd.enable = true;

        stateDir = "/home/sgiath/.openclaw";
        workspaceDir = "/home/sgiath/.openclaw/workspace";
      };
    };
  };
}
