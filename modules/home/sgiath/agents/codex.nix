{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "codex-temp" ''
        tmp="$(mktemp -d -p "$HOME" .codex-hook-trust.XXXXXX)"
        chmod 700 "$tmp"

        cp ~/.codex/auth.json "$tmp/auth.json"
        cp ~/.codex/config.toml "$tmp/config.toml"

        CODEX_HOME="$tmp" ${lib.getExe pkgs.llm-agents.codex} -C "''${1:-$PWD}"
      '')
    ];

    programs.codex = {
      enable = true;
      package = pkgs.llm-agents.codex;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      skills = ./skills;
      settings = {
        model = "gpt-5.5";
        model_reasoning_effort = "medium";
        service_tier = "fast";
        suppress_unstable_features_warning = true;
        personality = "pragmatic";

        tui.model_availability_nux."gpt-5.5" = 1;

        # https://developers.openai.com/codex/config-basic#supported-features
        features = {
          apps = true;
          memories = true;
          undo = true;
          plugin_hooks = true;
          codex_git_commit = true;
        };

        projects = {
          "${config.home.homeDirectory}/nixos".trust_level = "trusted";

          # personal projects
          "${config.home.homeDirectory}/develop/sgiath/sgiath.dev".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/bird".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/langchain".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/secp256k1".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/nostr".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/noise_protocol".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/advent-of-code".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/dragon_forge".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/erotom_dev".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/ex_astro".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/haven".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/playground".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/reticulum".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/sgiath/spaceboy".trust_level = "trusted";

          # CrazyEgg projects
          "${config.home.homeDirectory}/develop/crazyegg/core_v1".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/core_v2".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/skills".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/signal".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/k8s-config".trust_level = "trusted";
          "${config.home.homeDirectory}/develop/crazyegg/db-schemas".trust_level = "trusted";
        };

        hooks.state = {
          "${config.home.homeDirectory}/develop/crazyegg/core_v2/.codex/hooks.json:stop:0:0" = {
            trusted_hash = "sha256:5327d25062b16a8e306ee324a31b89e733a60a27a1d68cb53f2721c7b23c8b1a";
          };
        };
      };
    };

    programs.zsh.shellAliases = {
      cx = "${lib.getExe pkgs.llm-agents.codex} --yolo --dangerously-bypass-hook-trust";
    };
  };
}
