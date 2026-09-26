{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.file.".agents/skills".source = ./skills;
    home.sessionVariables.GROK_SANDBOX = "off";

    home.packages = [
      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird
      pkgs.nodejs
      pkgs.bun
      pkgs.sysstat
      pkgs.postgresql
      pkgs.valkey
      pkgs.poppler-utils
      pkgs.hyperfine

      # agents
      pkgs.llm-agents.cline
      pkgs.llm-agents.grok
      pkgs.llm-agents.openclaw
      pkgs.llm-agents.omo-ai

      # tools
      inputs.crit.packages.${pkgs.stdenv.hostPlatform.system}.crit
      pkgs.llm-agents.td
      pkgs.llm-agents.backlog-md
      pkgs.llm-agents.beads
      pkgs.llm-agents.qmd
      pkgs.llm-agents.codegraph
      pkgs.llm-agents.amp
      pkgs.llm-agents.plannotator
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.xurl
      pkgs.llm-agents.workmux

      # Hermes
      pkgs.llm-agents.hermes-agent
    ]
    ++ (lib.optionals config.sgiath.roles.desktop.enable [
      # x86_64-linux binary GUI editor; absent from pkgs.${namespace} on aarch64.
      pkgs.${namespace}.delta
      pkgs.llm-agents.hermes-desktop
      pkgs.llm-agents.grok-bot
      pkgs.${namespace}.openclaw-desktop
      pkgs.${namespace}.agent-orchestrator
    ]);

    programs.mcp = {
      enable = true;
      servers = {
        executor.url = "https://executor.sgiath.dev/mcp";
      };
    };
  };
}
