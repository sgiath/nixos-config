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
      custom-instructions = ./opencode/AGENTS.md;
      settings = {
        model = "gpt-5.4";
        model_reasoning_effort = "high";
        service_tier = "fast";
        suppress_unstable_features_warning = true;
        personality = "pragmatic";
        sandbox_mode = "danger-full-access";

        features = {
          undo = true;
          use_linux_sandbox_bwrap = true;
        };
      };
    };

    programs.zsh.shellAliases = {
      cx = "${codex}/bin/codex --dangerously-bypass-approvals-and-sandbox";
    };
  };
}
