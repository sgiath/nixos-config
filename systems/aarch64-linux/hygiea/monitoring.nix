# Watches home from outside and alerts through the public ntfy.sh, because
# Vesta's own ntfy is down exactly when it matters. The topic is secret
# (anyone who knows it can read and post); subscribe to it from
# `sops -d --extract '["gatus_env"]' secrets/hygiea.yaml`. Overlay checks are
# pings: Hygiea is untrusted, and peers admit only ICMP from lighthouses.
{ config, ... }:
let
  peers = config.sgiath.nebula.peers;
  ping = name: address: {
    inherit name;
    group = "home";
    url = "icmp://${address}";
    interval = "2m";
    conditions = [ "[CONNECTED] == true" ];
    alerts = [ { type = "ntfy"; } ];
  };
in
{
  sops.secrets.gatus_env.restartUnits = [ "gatus.service" ];

  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus_env.path;
    settings = {
      web = {
        address = "127.0.0.1";
        port = 8080;
      };
      alerting.ntfy = {
        url = "https://ntfy.sh";
        topic = "\${NTFY_TOPIC}";
        priority = 4;
        # About six minutes down before an alert, one message per transition;
        # ntfy.sh allows 250 messages a day without an account.
        default-alert = {
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };
      endpoints = [
        (ping "home internet" config.sgiath.publicIPv4)
      ]
      ++ map (name: ping name peers.${name}.ip4) [
        "vesta"
        "kvm-vesta"
        "kvm-ceres"
      ];
    };
  };
}
