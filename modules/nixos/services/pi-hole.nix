{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
  # Local records so phones and other non-Nix LAN clients resolve overlay
  # names the same way Nix hosts do via networking.hosts. The lighthouse name
  # gets the LAN address so Mobile Nebula at home does not hairpin the router.
  nebulaRecords = [
    "192.168.1.2 ${nebula.domain}"
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (name: peer: [
      "${peer.ip4} ${name}.${nebula.domain}"
      "${peer.ip6} ${name}.${nebula.domain}"
    ]) nebula.peers
  );
in
{
  options.services.pi-hole.enable = lib.mkEnableOption "pi-hole";

  config = lib.mkIf (config.sgiath.roles.server.enable && config.services.pi-hole.enable) {
    sops = {
      secrets.pihole-password = { };
      # FTL hashes FTLCONF_webserver_api_password at startup; settings coming
      # from the environment never touch the store-backed pihole.toml.
      templates.pihole-env = {
        restartUnits = [ "pihole-ftl.service" ];
        content = "FTLCONF_webserver_api_password=${config.sops.placeholder.pihole-password}";
      };
    };

    networking.networkmanager.dns = lib.mkForce "none";

    services.pihole-ftl = {
      enable = true;
      openFirewallDNS = true;
      queryLogDeleter.enable = true;
      lists = [
        {
          url = "https://big.oisd.nl/";
          description = "oisd big";
        }
        {
          url = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt";
          description = "Windows";
        }
      ];
      settings = {
        dns = {
          upstreams = [
            "8.8.8.8"
            "8.8.4.4"
            "1.1.1.1"
            "1.0.0.1"
          ];
          hosts = nebulaRecords;
        };
        # Keep public AAAA and HTTPS records from routing LAN clients through
        # Cloudflare, and never forward overlay names upstream. search.sgiath.dev
        # itself resolves from /etc/hosts (common/networking.nix).
        misc.dnsmasq_lines = lib.optional config.services.searx.enable "local=/search.sgiath.dev/" ++ [
          "local=/${nebula.domain}/"
        ];
      };
    };

    # On a fresh state dir the upstream setup script creates gravity.db, asks
    # FTL to reopen it and immediately posts lists; the first request can hit
    # "Database not available". Re-running is idempotent, so just retry.
    systemd.services.pihole-ftl-setup.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
    };

    systemd.services.pihole-ftl.serviceConfig.EnvironmentFile = config.sops.templates.pihole-env.path;

    services.pihole-web = {
      enable = true;
      hostName = "dns.sgiath";
      ports = [ "127.0.0.1:8053" ];
    };

    services.nginx = {
      virtualHosts."dns.sgiath" = {
        rejectSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8053";
            extraConfig = ''
              allow 127.0.0.1;
              allow ::1;
              deny 192.168.1.1;
              allow 192.168.1.0/24;
              deny all;
            '';
          };
        };
      };
    };
  };
}
