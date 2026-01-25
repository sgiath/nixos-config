{
  config,
  lib,
  pkgs,
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

    # patch clawdbot config: fix legacy keys (upstream bug)
    # telegram → channels.telegram, byProvider → byChannel
    home.activation.clawdbotConfigPatch = lib.hm.dag.entryAfter [ "clawdbotConfigFiles" ] ''
      CONFIG="/home/sgiath/.clawdbot/clawdbot.json"
      if [ -f "$CONFIG" ]; then
        ${pkgs.jq}/bin/jq '
          # move telegram → channels.telegram
          (if .telegram then .channels.telegram = .telegram | del(.telegram) else . end) |
          # move byProvider → byChannel
          (if .messages.queue.byProvider then .messages.queue.byChannel = .messages.queue.byProvider | del(.messages.queue.byProvider) else . end) |
          # explicitly set empty slots to override internal default
          .plugins = { slots: {}, entries: {}, load: { paths: [] } }
        ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
      fi
    '';
  };
}
