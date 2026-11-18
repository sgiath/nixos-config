{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cloudflare-warp;

  # The hostnames CrazyEgg's device profile routes through WARP (Include mode,
  # `warp-cli settings`). WARP adds a route for a name only when its own DNS
  # proxy answers it, so these zones go to the proxy and everything else stays
  # on the Pi-holes. Keep the list in step with the profile.
  warpZones = [
    "crazyegg.com"
    "crazyeggstaging.com"
    "crazyegg.cloudflareaccess.com"
    "accounts.google.com"
  ];
  # The proxy listens only while WARP is connected; the zones then fall
  # through to the Pi-holes.
  warpResolvers = [
    "127.0.2.2"
    "127.0.2.3"
  ];
  upstreams = config.sgiath.nebula.resolvers ++ [ "1.1.1.1" ];

  # Each upstream gets one second in order: Vesta's Pi-hole first, since
  # Hygiea's lacks the vhost records. No health tracking and no cache, so a
  # recovered server is used again on the next query. dnsmasq cannot do this:
  # its retries stay on the server that does not answer.
  forward = servers: ''
    forward . ${lib.concatStringsSep " " servers} {
      policy sequential
      max_fails 0
      read_timeout 1s
      max_connect_attempts ${toString (lib.length servers)}
      failover SERVFAIL REFUSED
    }
  '';

  # warp-svc points /etc/resolv.conf at its proxy and reapplies that whenever
  # the file changes. It gets a private /etc whose resolv.conf names the
  # Pi-holes directly, which it may rewrite and restore at will.
  warpResolvConf = pkgs.writeText "cloudflare-warp-resolv.conf" ''
    search sgiath.dev
    ${lib.concatMapStrings (ns: "nameserver ${ns}\n") upstreams}'';
  warpStart = pkgs.writeShellScript "cloudflare-warp-start" ''
    ln -s ${warpResolvConf} /etc/resolv.conf
    exec ${cfg.package}/bin/warp-svc
  '';
in
{
  config = lib.mkMerge [
    {
      services.cloudflare-warp.enable = lib.mkDefault (
        config.sgiath.enable && config.home-manager.users.sgiath.sgiath.work.crazyegg.warp.enable
      );
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !config.networking.resolvconf.enable;
          message = "services.cloudflare-warp: split DNS is only implemented for hosts with a static resolv.conf; resolvconf hosts (NetworkManager laptops) would also need the network's DHCP DNS among the upstreams, in CoreDNS and in WARP's private resolv.conf, for captive portals";
        }
      ];

      systemd.services.cloudflare-warp.serviceConfig = {
        ExecStart = lib.mkForce warpStart;
        ReadWritePaths = lib.mkForce [ cfg.rootDir ];
        TemporaryFileSystem = "/etc";
        BindReadOnlyPaths = [
          "/etc/static"
          "/etc/ssl"
          "/etc/pki"
          "/etc/hosts"
          "/etc/host.conf"
          "/etc/gai.conf"
          "/etc/nsswitch.conf"
          "/etc/os-release"
          "/etc/lsb-release"
          "/etc/machine-id"
          "/etc/passwd"
          "/etc/group"
        ];
        # libc would hand WARP's own lookups (its connectivity check) to the
        # host's nsncd, which resolves through the host resolv.conf and never
        # reaches WARP's proxy; WARP then reconnects in a loop.
        InaccessiblePaths = [ "/run/nscd" ];
      };

      services.coredns = {
        enable = true;
        config = ''
          ${lib.concatStringsSep " " (map (zone: "${zone}:53") warpZones)} {
            bind 127.0.0.1
            errors
            ${forward (warpResolvers ++ upstreams)}
          }

          .:53 {
            bind 127.0.0.1
            errors
            ${forward upstreams}
          }
        '';
      };

      # CoreDNS walks the upstreams itself, up to a second each.
      networking.nameservers = [ "127.0.0.1" ];
      environment.etc."resolv.conf".text = lib.mkForce ''
        search sgiath.dev
        options timeout:6 attempts:1
        nameserver 127.0.0.1
      '';

      # Docker replaces a loopback resolver with Google DNS for the default
      # bridge; containers keep the Pi-holes instead (CrazyEgg names resolve
      # publicly there).
      virtualisation.docker.daemon.settings.dns = lib.mkIf config.virtualisation.docker.enable upstreams;

      # The browser hands the Zero Trust login back through this scheme;
      # the package's desktop entry runs `warp-cli registration token`.
      xdg.mime.defaultApplications."x-scheme-handler/com.cloudflare.warp" = "com.cloudflare.warp.desktop";

      systemd.packages = [ cfg.package ];
      systemd.user.services.warp-taskbar.wantedBy = [ "graphical-session.target" ];
    })
  ];
}
