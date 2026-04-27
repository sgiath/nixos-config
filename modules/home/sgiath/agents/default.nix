{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./cursor.nix
    ./forge.nix
    ./opencode.nix
  ];

  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird

      # Cursor
      pkgs.cursor-cli

      # PI
      pkgs.pi-coding-agent

      # Hermes
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Node
    programs.npm.enable = true;
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
      };
    };
  };
}
