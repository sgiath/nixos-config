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
        gateway = {
          mode = "local";
          auth = "1234";
        };

        channels.telegram = {
          tokenFile = "/home/sgiath/.telegram-clawdbot";
          allowFrom = [ 5162798212 ];
          groups = {
            "*".requireMention = true;
          };
        };
      };

      instances.default = {
        enable = true;

        # plugins = [
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; }
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo"; }
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/oracle"; }
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/sag"; }
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/camsnap"; }
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/bird"; }
        #   { source = "github:joshp123/xuezh"; }
        # ];
      };
    };
  };
}
