{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.opencode = {
      enable = true;
      package = opencode;
      rules = ./opencode/AGENTS.md;
      agents = {
        explorer = ./opencode/agents/explorer.md;
      };
      commands = {
        commit = ./opencode/commands/commit.md;
        debug = ./opencode/commands/debug.md;
        handoff = ./opencode/commands/handoff.md;
        learn = ./opencode/commands/learn.md;
        start-work = ./opencode/commands/start-work.md;
        tech-debt = ./opencode/commands/tech-debt.md;
      };
      skills = {
        frontend-design = ./opencode/skills/frontend-design.md;
        tracer-bullet = ./opencode/skills/tracer-bullet.md;
      };
      settings = {
        # theme = "orng";
        autoupdate = false;
        permission = {
          bash = {
            "*" = "allow";
            "aws *" = "ask";
            "kubectl exec *" = "ask";
          };
          read = {
            "/nix/store/**" = "allow";
          };
          edit = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
          external_directory = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
        };
        server = {
          hostname = "0.0.0.0";
          mdns = true;
          cors = [
            "http://localhost:4096"
            "http://192.168.1.7:4096"
            "http://localhost:4097"
            "http://192.168.1.7:4097"
          ];
        };
        experimental = {
          batch_tool = true;
        };
      };

      web = {
        enable = true;
      };
    };
    stylix.targets.opencode.enable = false;

    # aliases
    programs.zsh.shellAliases = {
      oc = "OPENCODE_DISABLE_CLAUDE_CODE=true OPENCODE_ENABLE_EXA=1 ${lib.getExe opencode}";
    };
  };
}
