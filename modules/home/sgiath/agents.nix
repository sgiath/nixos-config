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

      firstParty = {
        summarize.enable = false; # Summarize web pages, PDFs, videos
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

      instances.default = {
        enable = true;
        # uses pkgs.clawdbot from overlay, which respects excludeTools
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
