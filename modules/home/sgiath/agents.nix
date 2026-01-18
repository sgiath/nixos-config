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
in
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
      package = codex;
    };
    programs.zsh.shellAliases.cx = "${codex}/bin/codex";

    # opencode
    programs.opencode = {
      enable = true;
      package = opencode;
      settings = {
        server = {
          port = 12345;
          hostname = "0.0.0.0";
        };
      };
    };
    programs.zsh.shellAliases.oc = "${opencode}/bin/opencode";
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "OpenCode Web Interface";
        After = [ "network.target" ];
      };
      Service = {
        Environment = {
          OPENCODE_SERVER_PASSWORD = "";
        };
        ExecStart = "${opencode}/bin/opencode web --host 0.0.0.0 --port 12345";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
