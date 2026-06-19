{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../../secrets.json);
  aoe = inputs.aoe.packages.${pkgs.stdenv.hostPlatform.system}.aoe-with-web;
  agentPath = lib.makeBinPath [
    aoe
    pkgs.bash
    pkgs.coreutils
    pkgs.git
    pkgs.nodejs
    pkgs.openssh
    pkgs.tmux
    pkgs.llm-agents.codex
    pkgs.llm-agents.cursor-agent
    pkgs.llm-agents.hermes-agent
    pkgs.llm-agents.opencode
    pkgs.llm-agents.pi
  ];
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ aoe ];

    systemd.user.services.aoe-serve = {
      Unit = {
        Description = "Agent of Empires web dashboard";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Environment = [
          "AOE_SERVE_PASSPHRASE=${secrets.aoePassword}"
          "HOME=${config.home.homeDirectory}"
          "PATH=${agentPath}"
        ];
        ExecStart = "${lib.getExe aoe} serve --host 0.0.0.0 --port 62361 --auth=passphrase --behind-proxy";
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = config.home.homeDirectory;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
