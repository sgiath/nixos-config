{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  codex = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default;
  pkgs-oc = pkgs.openclawPackages.withTools { excludeToolNames = [ "git" ]; }
in
{
  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs-oc.openclaw
      pkgs.python3
      pkgs.${namespace}.bird

      # CodeRabbit
      # pkgs.${namespace}.coderabbit

      # Claude Code
      # pkgs.${namespace}.claude-code-acp

      # LLM tools
      inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default
      # pkgs.${namespace}.agent-of-empires
      # pkgs.${namespace}.gastown
      # inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      # pkgs.${namespace}.bdui
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
      cx = "${codex}/bin/codex --full-auto";
    };

    # bun
    programs.bun.enable = true;
  };
}
