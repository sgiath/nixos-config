{ config, lib, ... }:
let
  cfg = config.sgiath.nebula;
  net = config.services.nebula.networks.sgiath;
  hostName = config.networking.hostName;
  lighthouse = cfg.peers.vesta;
  # Overlay addresses; hosts with a fixed LAN address mirror its last octet,
  # non-NixOS devices (Mobile Nebula, scripts/nebula-mobile.sh) start at .20.
  # Certificates come from scripts/nebula-sign.sh, keyed by peer name.
  peers = {
    vesta = {
      ip4 = "10.42.0.2";
      ip6 = "fd51:da00:4788::2";
    };
    ceres = {
      ip4 = "10.42.0.6";
      ip6 = "fd51:da00:4788::6";
    };
    pallas = {
      ip4 = "10.42.0.9";
      ip6 = "fd51:da00:4788::9";
    };
    juno1 = {
      ip4 = "10.42.0.11";
      ip6 = "fd51:da00:4788::11";
    };
    phone = {
      ip4 = "10.42.0.20";
      ip6 = "fd51:da00:4788::20";
    };
  };
  peerType = lib.types.submodule {
    options = {
      ip4 = lib.mkOption { type = lib.types.str; };
      ip6 = lib.mkOption { type = lib.types.str; };
    };
  };
in
{
  options.sgiath.nebula = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "nebula.sgiath.dev";
      readOnly = true;
      description = "DNS suffix for overlay host names (<host>.<domain>); also the lighthouse's public name.";
    };
    peers = lib.mkOption {
      type = lib.types.attrsOf peerType;
      default = peers;
      readOnly = true;
      description = "Overlay addresses of every Nebula host, keyed by hostname.";
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

  config = lib.mkIf config.sgiath.enable {
    services.nebula.networks.sgiath = {
      ca = config.sops.secrets.nebula-ca.path;
      cert = config.sops.secrets.nebula-cert.path;
      key = config.sops.secrets.nebula-key.path;

      # Vesta sets isLighthouse/isRelay in its host config; everyone else
      # discovers peers through it and falls back to relaying when hole
      # punching fails. nebula.sgiath.dev is a DNS-only record for the home
      # public address (UDP cannot traverse the Cloudflare proxy); at home the
      # networking.nix hosts entry resolves it to the LAN address instead.
      lighthouses = lib.mkIf (!net.isLighthouse) [
        lighthouse.ip4
        lighthouse.ip6
      ];
      relays = lib.mkIf (!net.isRelay) [
        lighthouse.ip4
        lighthouse.ip6
      ];
      staticHostMap = {
        ${lighthouse.ip4} = [ "${cfg.domain}:4242" ];
        ${lighthouse.ip6} = [ "${cfg.domain}:4242" ];
      };
      listen.host = "[::]";

      # Every peer holds a certificate signed by our CA; that is the auth.
      # Services bound to the nebula interface need no login of their own.
      firewall = {
        outbound = [
          {
            port = "any";
            proto = "any";
            host = "any";
          }
        ];
        inbound = [
          {
            port = "any";
            proto = "any";
            host = "any";
          }
        ];
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
          sopsFile = ../../../secrets/nebula.yaml;
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
          ${lighthouse.ip4} = map (name: "${name}.sgiath.dev") cfg.services;
          ${lighthouse.ip6} = map (name: "${name}.sgiath.dev") cfg.services;
        }
      ]
    );
  };
}
