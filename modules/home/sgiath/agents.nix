{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  forge = inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.python3
      pkgs.uv
      pkgs.${namespace}.bird
      pkgs.bubblewrap

      # ForgeCode
      forge

      # Hermes
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # claude code
    programs.claude-code = {
      enable = false;
      package = pkgs.claude-code;
    };

    # aliases
    # programs.zsh.shellAliases = {
    #   cc = "${lib.getExe pkgs.claude-code} --dangerously-skip-permissions";
    # };

    # ForgeCode shell integration
    # programs.zsh.initContent = lib.mkAfter ''
    #   if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
    #     eval "$(${lib.getExe forge} zsh plugin)"
    #   fi

    #   if [[ -z "$_FORGE_THEME_LOADED" ]]; then
    #     eval "$(${lib.getExe forge} zsh theme)"
    #   fi
    # '';

    # bun
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
