{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../../secrets.json);
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
      # pkgs.${namespace}.bird
      pkgs.nodejs

      # Cursor
      # pkgs.cursor-cli

      pkgs.${namespace}.fusion
      pkgs.${namespace}.plannotator
      pkgs.${namespace}.qmd

      # Hermes
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

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

        datadog = {
          url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp?toolsets=all";
        };

        gate-agent = {
          url = "https://gate-agent.crazyegg.com/mcp";
          headers = {
            Authorization = "Bearer ${secrets.gate-agent_api_key}";
          };
        };
      };
    };
  };
}
