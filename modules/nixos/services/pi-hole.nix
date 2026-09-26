{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
  # Local records so phones and other non-Nix LAN clients resolve overlay
  # names the same way Nix hosts do via networking.hosts. The lighthouse name
  # gets the LAN address so Mobile Nebula at home does not hairpin the router.
  vesta = nebula.peers.vesta;
  lan = {
    ip4 = "192.168.1.2";
    ip6 = "fd39:f21:ea9::2";
  };
  nebulaRecords = [
    "${lan.ip4} ${nebula.domain}"
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (name: peer: [
      "${peer.ip4} ${name}.${nebula.domain}"
      "${peer.ip6} ${name}.${nebula.domain}"
    ]) nebula.peers
  )
  ++ lib.concatMap (name: [
    "${vesta.ip4} ${name}.sgiath.dev"
    "${vesta.ip6} ${name}.sgiath.dev"
  ]) nebula.services;
  # Public HTTPS names served by this nginx, minus the overlay-only services
  # above, resolve to Vesta directly instead of through Cloudflare or the
  # router's NAT hairpin. localise-queries returns the IPv4 address on the
  # interface the query arrived on: LAN clients get the LAN address, Mobile
  # Nebula gets the overlay one from anywhere. dnsmasq localises only IPv4, so
  # AAAA is the LAN ULA alone; RFC 6724 ranks ULA below IPv4, so off-LAN
  # Nebula clients keep using IPv4. Omitting AAAA would forward it to Cloudflare.
  publicNames = lib.subtractLists (map (name: "${name}.sgiath.dev") nebula.services) (
    lib.concatLists (
      lib.mapAttrsToList (
        name: vhost:
        lib.optionals (vhost.onlySSL || vhost.addSSL || vhost.forceSSL) ([ name ] ++ vhost.serverAliases)
      ) config.services.nginx.virtualHosts
    )
  );
  publicRecords = lib.concatMap (
    name:
    map (ip: "${ip} ${name}") [
      lan.ip4
      lan.ip6
      vesta.ip4
    ]
  ) publicNames;
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
        # Keep public AAAA and HTTPS records from routing LAN clients through
        # Cloudflare, and never forward overlay names upstream.
        misc.dnsmasq_lines =
          map (name: "local=/${name}.sgiath.dev/") nebula.services
          ++ [ "local=/${nebula.domain}/" ]
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
