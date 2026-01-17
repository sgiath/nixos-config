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

      # Claude Code
      pkgs.${namespace}.claude-code-acp
      pkgs.${namespace}.openspec
      pkgs.${namespace}.gastown
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.${namespace}.bdui
    ];
    programs.zsh.shellAliases.os = "${pkgs.${namespace}.openspec}/bin/openspec";

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };
    programs.zsh.shellAliases.cc = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";

    # Codex
    programs.codex = {
      enable = true;
      package = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
    programs.zsh.shellAliases.cx = "${
      inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/codex";

    # opencode
    programs.opencode = {
      enable = true;
      package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
    programs.zsh.shellAliases.oc = "${
      inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/opencode";
  };
}
