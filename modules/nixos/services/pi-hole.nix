{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
  # Local records so phones and other non-Nix clients resolve overlay names the
  # same way Nix hosts do via networking.hosts. Records are Nebula IPv4 only;
  # the lighthouse name itself has no local record and resolves upstream.
  vesta = nebula.peers.vesta;
  peerNames = lib.mapAttrsToList (name: _: "${name}.${nebula.domain}") nebula.peers;
  nebulaRecords =
    lib.mapAttrsToList (name: peer: "${peer.ip4} ${name}.${nebula.domain}") nebula.peers
    ++ map (name: "${vesta.ip4} ${name}.sgiath.dev") nebula.services;
  # Public HTTPS names served by this nginx, minus the overlay-only services
  # above, resolve to Vesta's Nebula address instead of through Cloudflare or
  # the router's NAT hairpin. They have no local AAAA, so AAAA queries go
  # upstream and IPv6 clients get Cloudflare where the name is proxied.
  publicNames = lib.subtractLists (map (name: "${name}.sgiath.dev") nebula.services) (
    lib.concatLists (
      lib.mapAttrsToList (
        name: vhost:
        lib.optionals (vhost.onlySSL || vhost.addSSL || vhost.forceSSL) ([ name ] ++ vhost.serverAliases)
      ) config.services.nginx.virtualHosts
    )
  );
  publicRecords = map (name: "${vesta.ip4} ${name}") publicNames;
  # Cloudflare's HTTPS records carry edge IP hints and an ECH config that nginx
  # cannot accept, so answer "1 . alpn=h2,http/1.1" locally. Unlike local=,
  # this keeps MX, TXT, SRV and subdomains of apex names resolving upstream.
  publicHttpsRecords = map (
    name: "dns-rr=${name},65,0001000001000c02683208687474702f312e31"
  ) publicNames;
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
          hosts = nebulaRecords ++ publicRecords;
          # The Turris resolver forwards every LAN query here without validating,
          # because it would reject the local sgiath.dev and blocked answers as
          # bogus. Validate here instead; all LAN traffic arrives from the router,
          # so a per-client rate limit would throttle the whole network.
          dnssec = true;
          rateLimit.count = 0;
        };
        # Keep public HTTPS records from routing clients through Cloudflare,
        # and never forward overlay names upstream.
        misc.dnsmasq_lines =
          map (name: "local=/${name}.sgiath.dev/") nebula.services
          ++ map (name: "local=/${name}/") peerNames
          ++ publicHttpsRecords;
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
