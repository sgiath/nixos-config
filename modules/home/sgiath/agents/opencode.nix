{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    # intentionally not using opencode module since opencode really wants to update its config
    # in place and managing it through Nix is more pain then benefits

    home.packages = [ pkgs.llm-agents.opencode ];
    xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;
    stylix.targets.opencode.enable = false;

    programs.zsh.shellAliases = {
      oc = "${lib.getExe pkgs.llm-agents.opencode} attach http://localhost:4096";
    };

    systemd.user.services.opencode = {
      Unit = {
        Description = "OpenCode web";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        # Environment = [
        #   "OPENCODE_SERVER_USERNAME=sgiath"
        #   "OPENCODE_SERVER_PASSWORD=${secrets.opencodePassword}"
        # ];
        ExecStart = "${lib.getExe pkgs.llm-agents.opencode} web";
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = config.home.homeDirectory;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
