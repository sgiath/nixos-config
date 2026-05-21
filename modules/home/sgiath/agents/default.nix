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

      pkgs.${namespace}.coderabbit
      pkgs.${namespace}.fusion
      pkgs.${namespace}.plannotator
      pkgs.${namespace}.qmd
      pkgs.${namespace}.clawpatch
      pkgs.${namespace}.linear-cli
      pkgs.${namespace}.beadboard

      # Hermes
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      (inputs.gas-town.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
        __intentionallyOverridingVersion = true;
        version = "1.1.0";
        vendorHash = "sha256-PQT/Xq9na3vI8Oy9INBYJf3GsiN5IxAVCxrNLhyIpO8=";
      }))
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

        datadog.url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp?toolsets=all";
        linear.url = "https://mcp.linear.app/mcp";
      };
    };
  };
}
