{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.openclaw.enable {
    programs.openclaw = {
      documents = ./openclaw;

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
        plugins = [
          { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; }
          { source = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo"; }
          { source = "github:openclaw/nix-steipete-tools?dir=tools/oracle"; }
          { source = "github:openclaw/nix-steipete-tools?dir=tools/sag"; }
          { source = "github:openclaw/nix-steipete-tools?dir=tools/camsnap"; }
          { source = "github:openclaw/nix-steipete-tools?dir=tools/bird"; }
          { source = "github:joshp123/xuezh"; }
        ];
      };
    };
  };
}
