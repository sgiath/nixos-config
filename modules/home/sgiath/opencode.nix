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
    home.packages = [
      opencode
    ];

    # aliases
    programs.zsh.shellAliases = {
      oc = "${opencode}/bin/opencode attach http://localhost:4096 --dir $(pwd)";
      omo = "${opencode}/bin/opencode attach http://localhost:4097 --dir $(pwd)";
    };

    systemd.user.services = {
      opencode-vanilla = {
        Unit = {
          Description = "OpenCode vanilla Server";
        };
        Service = {
          Environment = [
            "OPENCODE_SERVER_PASSWORD=\"\""
            "OPENCODE_CONFIG=${config.xdg.configHome}/opencode/vanilla/opencode.jsonc"
            "OPENCODE_CONFIG_DIR=${config.xdg.configHome}/opencode/vanilla"
            ""
          ];
          ExecStart = "${opencode}/bin/opencode serve --port 4096";
        };
        Install = {
          WantedBy = [ "multi-user.target" ];
        };
      };

      opencode-omo = {
        Unit = {
          Description = "OpenCode oh-my-opencode Server";
        };
        Service = {
          Environment = [
            "OPENCODE_SERVER_PASSWORD=\"\""
            "OPENCODE_CONFIG=${config.xdg.configHome}/opencode/omo/opencode.jsonc"
            "OPENCODE_CONFIG_DIR=${config.xdg.configHome}/opencode/omo"
            ""
          ];
          ExecStart = "${opencode}/bin/opencode serve --port 4097";
        };
        Install = {
          WantedBy = [ "multi-user.target" ];
        };
      };
    };
  };
}
