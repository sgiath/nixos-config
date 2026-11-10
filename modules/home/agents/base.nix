{
  config,
  inputs,
  lib,
  pkgs,
  namespace,
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

      # formatters and linters agents call directly, outside `nix develop`
      pkgs.nixfmt
      pkgs.shfmt
      pkgs.shellcheck

      # agents
      pkgs.llm-agents.grok
      pkgs.llm-agents.omo-ai

      # tools
      pkgs.llm-agents.qmd
      pkgs.llm-agents.workmux

      # Hermes
      pkgs.llm-agents.hermes-agent
    ]
    # Upstream ships only an amd64 Linux build; absent from pkgs.${namespace} on aarch64.
    ++ (lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      pkgs.${namespace}.whiteboard
    ])
    ++ (lib.optionals config.sgiath.roles.desktop.enable [
      inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta
      pkgs.llm-agents.hermes-desktop
      pkgs.llm-agents.grok-bot
      # Drives the desktop Chromium through the browse extension; `browse
      # install` adopts this package and configures agents Nix does not manage.
      pkgs.${namespace}.browse
    ]);

    programs.mcp = {
      enable = true;
      servers = {
        executor.url = "https://executor.sgiath.dev/mcp";
        browse = lib.mkIf config.sgiath.roles.desktop.enable {
          command = lib.getExe pkgs.${namespace}.browse;
          args = [ "mcp" ];
        };
      };
    };
  };
}
