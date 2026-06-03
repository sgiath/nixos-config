{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  backlog-md = inputs.backlog-md.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./cursor.nix
    ./forge.nix
    ./opencode.nix
    ./pi.nix
  ];

  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird
      pkgs.nodejs

      backlog-md

      pkgs.llm-agents.openspec
      pkgs.llm-agents.beads
      pkgs.llm-agents.coderabbit-cli
      pkgs.llm-agents.qmd
      pkgs.llm-agents.grok

      pkgs.${namespace}.fusion
      pkgs.${namespace}.plannotator
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.linear-cli
      pkgs.${namespace}.xurl

      # Hermes
      # inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.llm-agents.hermes-agent
      pkgs.llm-agents.hermes-desktop
      pkgs.llm-agents.hermes-hud

      # T3 code
      (lib.mkIf (config.sgiath.targets.graphical) pkgs.${namespace}.t3code)
    ];

    programs.zsh.shellAliases = {
      bl = "${lib.getExe backlog-md}";
      gr = "${lib.getExe pkgs.llm-agents.grok} --experimental-memory";
    };

    # Node
    programs.bun.enable = true;

    programs.mcp = {
      enable = true;

      servers = {
        github = {
          command = "npx";
          args = [
            "-y"
            "@modelcontextprotocol/server-github"
          ];
        };

        datadog.url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp?toolsets=all";
        linear.url = "https://mcp.linear.app/mcp";
        notion.url = "https://mcp.notion.com/mcp";
      };
    };
  };
}
