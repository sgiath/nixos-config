{ config, lib, ... }:
let
  cfg = config.sgiath.nebula;
  net = config.services.nebula.networks.sgiath;
  hostName = config.networking.hostName;
  # Overlay addresses; hosts with a fixed LAN address mirror its last octet,
  # non-NixOS devices (Mobile Nebula, scripts/nebula-mobile.sh) start at .20.
  # Certificates come from scripts/nebula-sign.sh, keyed by peer name.
  peers = {
    vesta = {
      ip4 = "10.42.0.2";
      ip6 = "fd51:da00:4788::2";
      trusted = true;
      lighthouse = [ "${config.sgiath.publicIPv4}:4242" ];
    };
    # Backup lighthouse/relay, Pi-hole and backup target on Oracle Cloud
    # (systems/aarch64-linux/hygiea); keeps the overlay up while Vesta is down.
    hygiea = {
      ip4 = "10.42.0.3";
      ip6 = "fd51:da00:4788::3";
      # Ephemeral public IP: it survives stop/start but not terminating the
      # instance. A replacement means a new address here and in OCI. Port 443
      # is redirected to 4242 on Hygiea for networks (hotels) that pass
      # outbound UDP only to well-known ports.
      lighthouse = [
        "92.5.169.98:4242"
        "92.5.169.98:443"
      ];
    };
    ceres = {
      ip4 = "10.42.0.6";
      ip6 = "fd51:da00:4788::6";
      trusted = true;
    };
    pallas = {
      ip4 = "10.42.0.9";
      ip6 = "fd51:da00:4788::9";
      trusted = true;
    };
    juno1 = {
      ip4 = "10.42.0.11";
      ip6 = "fd51:da00:4788::11";
      trusted = true;
    };
    phone = {
      ip4 = "10.42.0.20";
      ip6 = "fd51:da00:4788::20";
      trusted = true;
    };
    # JetKVMs (scripts/nebula-jetkvm.sh), named after the machine they control.
    kvm-vesta = {
      ip4 = "10.42.0.21";
      ip6 = "fd51:da00:4788::21";
    };
    kvm-ceres = {
      ip4 = "10.42.0.22";
      ip6 = "fd51:da00:4788::22";
    };
  };
  peerType = lib.types.submodule {
    options = {
      ip4 = lib.mkOption { type = lib.types.str; };
      ip6 = lib.mkOption { type = lib.types.str; };
      trusted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Admit the peer's inbound connections on every host. Untrusted peers
          are still reachable: Nebula's firewall is stateful, so replies to
          connections a host opens pass.
        '';
      };
      lighthouse = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Public `ip:port` endpoints of a lighthouse; peers try all of them.
          Every lighthouse is also a relay, and every other peer registers
          with all of them.
        '';
      };
    };
  };
  lighthouses = lib.filterAttrs (name: peer: peer.lighthouse != [ ] && name != hostName) cfg.peers;
  lighthouseIPs = lib.concatMap (peer: [
    peer.ip4
    peer.ip6
  ]) (lib.attrValues lighthouses);
in
{
  options.sgiath.nebula = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.sgiath.enable;
      defaultText = lib.literalExpression "config.sgiath.enable";
      description = "Join the overlay; hosts without the baseline (Hygiea) enable it alone.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../secrets/nebula.yaml;
      description = ''
        SOPS file with `ca_crt` and this host's `<host>_cert`/`<host>_key`.
        Untrusted hosts get their own file so they cannot decrypt the others' keys.
      '';
    };
    resolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        peers.vesta.ip4
        peers.hygiea.ip4
      ];
      readOnly = true;
      description = "Overlay addresses of the Pi-hole instances, in order of preference.";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "nebula.sgiath.dev";
      readOnly = true;
      description = "DNS suffix for overlay host names (<host>.<domain>); also Vesta's public lighthouse name.";
    };
    peers = lib.mkOption {
      type = lib.types.attrsOf peerType;
      default = peers;
      readOnly = true;
      description = "Overlay addresses, trust and lighthouse endpoints of every Nebula peer, keyed by certificate name.";
    };
    cidr4 = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.0/24";
      readOnly = true;
      description = "Overlay IPv4 range; nginx `allow` for overlay-only services.";
    };
    cidr6 = lib.mkOption {
      type = lib.types.str;
      default = "fd51:da00:4788::/64";
      readOnly = true;
      description = "Overlay IPv6 range; nginx `allow` for overlay-only services.";
    };
    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Services Vesta exposes only on the overlay. Each name resolves as
        <name>.sgiath.dev to Vesta's overlay addresses on every host and in
        Pi-hole (no public record exists); the service module restricts its
        nginx vhost to the CIDRs. Certificates still come from Let's Encrypt
        via DNS-01, which is why the names stay under the public zone.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nebula.networks.sgiath = {
      ca = config.sops.secrets.nebula-ca.path;
      cert = config.sops.secrets.nebula-cert.path;
      key = config.sops.secrets.nebula-key.path;

      # Peers with a lighthouse endpoint serve as lighthouse and relay; the
      # others register with all of them and fall back to relaying when hole
      # punching fails. A peer advertises its relays to the lighthouses, so
      # every peer lists all of them. The endpoints are numeric so
      # bootstrapping never depends on DNS, which itself runs over the tunnel.
      isLighthouse = cfg.peers.${hostName}.lighthouse != [ ];
      isRelay = net.isLighthouse;
      lighthouses = lib.mkIf (!net.isLighthouse) lighthouseIPs;
      relays = lib.mkIf (!net.isRelay) lighthouseIPs;
      staticHostMap = lib.concatMapAttrs (_: peer: {
        ${peer.ip4} = peer.lighthouse;
        ${peer.ip6} = peer.lighthouse;
      }) lighthouses;
      listen.host = "[::]";

      # A trusted peer's certificate is the auth, so services bound to the
      # nebula interface need no login of their own. Inbound is an allowlist
      # of trusted peers by certificate name; lighthouses may also ping, so
      # Hygiea can monitor home from outside.
      firewall = {
        outbound = [
          {
            port = "any";
            proto = "any";
            host = "any";
          }
        ];
        inbound =
          lib.mapAttrsToList (name: _: {
            port = "any";
            proto = "any";
            host = name;
          }) (lib.filterAttrs (_: peer: peer.trusted) cfg.peers)
          ++ lib.mapAttrsToList (name: _: {
            port = "any";
            proto = "icmp";
            host = name;
          }) lighthouses;
      };

      settings.punchy = {
        punch = true;
        respond = true;
      };
    };

    sops.secrets =
      let
        secret = key: {
          inherit key;
          sopsFile = cfg.secretsFile;
          owner = net.user;
          group = net.group;
          mode = "0400";
          restartUnits = [ "nebula@sgiath.service" ];
        };
      in
      {
        nebula-ca = secret "ca_crt";
        nebula-cert = secret "${hostName}_cert";
        nebula-key = secret "${hostName}_key";
      };

    # <host>.nebula.sgiath.dev and <service>.sgiath.dev resolve to the overlay
    # addresses everywhere, independent of the current resolver.
    networking.hosts = lib.mkMerge (
      lib.mapAttrsToList (name: peer: {
        ${peer.ip4} = [ "${name}.${cfg.domain}" ];
        ${peer.ip6} = [ "${name}.${cfg.domain}" ];
      }) cfg.peers
      ++ [
        {
          ${cfg.peers.vesta.ip4} = map (name: "${name}.sgiath.dev") cfg.services;
          ${cfg.peers.vesta.ip6} = map (name: "${name}.sgiath.dev") cfg.services;
        }
      ]
    );
  };
}
