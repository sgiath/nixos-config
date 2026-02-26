{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  codex = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.codex-rs;
  # codex = pkgs.codex;
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

      # Claude Code
      # pkgs.${namespace}.claude-code-acp

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };

    # Codex
    programs.codex = {
      enable = true;
      package = codex;
    };

    # aliases
    programs.zsh.shellAliases = {
      cc = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";
      cx = "${codex}/bin/codex --dangerously-bypass-approvals-and-sandbox";
    };

    # bun
    programs.bun.enable = true;
  };
}
