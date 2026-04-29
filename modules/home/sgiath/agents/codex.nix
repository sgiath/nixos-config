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
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      skills = ./skills;
      settings = {
        model = "gpt-5.5";
        model_reasoning_effort = "medium";
        service_tier = "fast";
        suppress_unstable_features_warning = true;
        personality = "pragmatic";

        # https://developers.openai.com/codex/config-basic#supported-features
        features = {
          apps = true;
          memories = true;
          undo = true;
        };

        projects = {
          "${config.home.homeDirectory}/nixos".trust_level = "trusted";

          # personal projects
          "${config.home.homeDirectory}/develop/sgiath/sgiath.dev".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/bird".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/langchain".trust_level = "trusted";

          # CrazyEgg projects
          "${config.home.homeDirectory}/develop/crazyegg/core_v2".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/skills".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/signal".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/k8s-config".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/db-schemas".trust_level = "trusted";
        };
      };
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe codex} --yolo";
    };
  };
}
