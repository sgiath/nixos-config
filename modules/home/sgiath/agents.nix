{
  config,
  lib,
  pkgs,
  inputs,
  # namespace,
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

      # opencode
      opencode
      # inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.desktop
      # pkgs.${namespace}.openwork

      # CodeRabbit
      # pkgs.${namespace}.coderabbit

      # Claude Code
      # pkgs.${namespace}.claude-code-acp

      # LLM tools
      openspec
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
      oc = "${opencode}/bin/opencode attach http://localhost:4096 --dir $(pwd)";
      oc-serve = "OPENCODE_SERVER_PASSWORD=\"\" ${opencode}/bin/opencode serve --cors http://localhost:4096 --cors https://opencode.sgiath.dev --port 4096 --hostname 0.0.0.0";
      cc = "${pkgs.claude-code}/bin/claude --dangerously-skip-permissions";
      cx = "${codex}/bin/codex --full-auto";
    };

    # bun
    programs.bun.enable = true;
  };
}
