{
  config,
  pkgs,
  lib,
  ...
}:
let
  # codex = inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.codex-rs;
  codex = pkgs.codex;
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.codex = {
      enable = true;
      package = codex;
      custom-instructions = builtins.readFile ./opencode/AGENTS.md;
      settings = {
        model = "gpt-5.4";
        model_reasoning_effort = "high";
        service_tier = "fast";
        suppress_unstable_features_warning = true;
        personality = "pragmatic";
        sandbox_mode = "danger-full-access";

        mcp_servers = {
          datadog.url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp";
        };

        features = {
          undo = true;
          use_linux_sandbox_bwrap = true;
        };
      };
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe codex} --dangerously-bypass-approvals-and-sandbox";
    };
  };
}
