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
      enable = false;
      package = opencode;
      settings = {
        theme = "orng";
        autoupdate = false;
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
        permissions = {
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
    };

    # aliases
    programs.zsh.shellAliases = {
      oc = "OPENCODE_DISABLE_CLAUDE_CODE=true ${opencode}/bin/opencode";
    };

    # systemd.user.services = {
    #   opencode-vanilla = {
    #     Unit.Description = "OpenCode vanilla Server";
    #     Service = {
    #       Environment = [
    #         "OPENCODE_SERVER_PASSWORD=\"\""
    #         "OPENCODE_EXPERIMENTAL_PLAN_MODE=1"
    #         "OPENCODE_DISABLE_CLAUDE_CODE=true"
    #         "OPENCODE_CONFIG=${config.xdg.configHome}/opencode/vanilla/opencode.jsonc"
    #         "OPENCODE_CONFIG_DIR=${config.xdg.configHome}/opencode/vanilla"
    #       ];
    #       ExecStart = "${opencode}/bin/opencode serve --port 4096";
    #     };
    #     Install = {
    #       WantedBy = [ "multi-user.target" ];
    #     };
    #   };

    #     opencode-omo = {
    #       Unit = {
    #         Description = "OpenCode oh-my-opencode Server";
    #       };
    #       Service = {
    #         Environment = [
    #           "OPENCODE_SERVER_PASSWORD=\"\""
    #           "OPENCODE_DISABLE_CLAUDE_CODE=true"
    #           "OPENCODE_CONFIG=${config.xdg.configHome}/opencode/omo/opencode.jsonc"
    #           "OPENCODE_CONFIG_DIR=${config.xdg.configHome}/opencode/omo"
    #         ];
    #         ExecStart = "${opencode}/bin/opencode serve --port 4097";
    #       };
    #       Install = {
    #         WantedBy = [ "multi-user.target" ];
    #       };
    #     };
    #   };
  };
}
