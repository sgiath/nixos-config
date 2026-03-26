{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
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

      # Claude Code
      pkgs.${namespace}.claude-agent-acp

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };

    # aliases
    programs.zsh.shellAliases = {
      cc = "${lib.getExe pkgs.claude-code} --dangerously-skip-permissions";
    };

    # bun
    programs.bun.enable = true;
  };
}
