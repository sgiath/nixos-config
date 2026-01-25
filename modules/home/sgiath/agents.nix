{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # opencode = pkgs.opencode;
  codex = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.python3

      # CodeRabbit
      pkgs.${namespace}.coderabbit

      # Claude Code
      pkgs.${namespace}.claude-code-acp
      pkgs.${namespace}.openspec
      pkgs.${namespace}.gastown
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.${namespace}.bdui
    ];
    programs.zsh.shellAliases.os = "${pkgs.${namespace}.openspec}/bin/openspec";

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };
    programs.zsh.shellAliases.cc = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";

    # Codex
    programs.codex = {
      enable = true;
      package = codex;
    };
    programs.zsh.shellAliases.cx = "${codex}/bin/codex";

    # opencode
    programs.opencode = {
      enable = true;
      package = opencode;
    };
    programs.zsh.shellAliases.oc = "${opencode}/bin/opencode";

    # clawdbot
    programs.clawdbot = {
      enable = true;
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
          (if .messages.queue.byProvider then .messages.queue.byChannel = .messages.queue.byProvider | del(.messages.queue.byProvider) else . end)
        ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
      fi
    '';
  };
}
