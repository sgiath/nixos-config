{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
{
  config = lib.mkIf config.programs.vscode.enable {
    home.packages = [
      # Claude Code
      pkgs.${namespace}.claude-code-acp
      pkgs.${namespace}.openspec
      pkgs.python3

      # gas town
      pkgs.${namespace}.gastown

      # Beads
      inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.${namespace}.bdui
    ];

    # claude code
    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
    };
    programs.zsh.shellAliases.cc = "${pkgs.claude-code}/bin/claude --allow-dangerously-skip-permissions";

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
