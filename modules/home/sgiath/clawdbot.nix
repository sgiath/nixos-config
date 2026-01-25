{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.clawdbot.enable {
    programs.clawdbot = {
      documents = ./clawdbot;
      excludeTools = [ "summarize" ]; # conflicts with clawdbot's own /bin/summarize

      instances.default = {
        enable = true;
        stateDir = "/home/sgiath/.clawdbot";
        workspaceDir = "/home/sgiath/.clawdbot/workspace";

        providers.telegram = {
          enable = true;
          botTokenFile = "/home/sgiath/.telegram-clawdbot";
          allowFrom = [ 5162798212 ];
        };

        providers.anthropic.apiKeyFile = "/home/sgiath/.anthropic-api-key";

        launchd.enable = true;
      };
    };
  };
}
