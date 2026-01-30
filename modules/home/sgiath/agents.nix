{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codex = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default;
  openspec = inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.sgiath.agents = {
    enable = lib.mkEnableOption "LLM agents";
  };

  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      pkgs.python3

      # CodeRabbit
      pkgs.${namespace}.coderabbit

      # Claude Code
      pkgs.${namespace}.claude-code-acp

      # LLM tools
      openspec
      pkgs.${namespace}.gastown
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.${namespace}.bdui
      pkgs.${namespace}.openwork
      inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.desktop
    ];
    programs.zsh.shellAliases.os = "${openspec}/bin/openspec";

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };
    programs.zsh.shellAliases.cc = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";

    # Codex
    programs.codex = {
      enable = true;
      package = codex;
    };
    programs.zsh.shellAliases.cx = "${codex}/bin/codex --full-auto";

    # opencode
    programs.opencode = {
      enable = true;
      package = opencode;
      settings = {
        plugin = [
        ];
      };
    };
    programs.zsh.shellAliases.oc = "${opencode}/bin/opencode";

    # bun
    programs.bun.enable = true;
  };
}
