{ pkgs, ... }:
let
  # Vesta's nginx owns 80/443 and SearXNG holds 127.0.0.1:8080, so dev-nginx
  # moves to loopback ports the `crazyeggdev` site proxies to. dev-nginx
  # reaches containers and host-run apps through `host.docker.internal`; the
  # pinned bridge gateway makes that address fixed, and services it proxies to
  # publish on that gateway too. Nothing is published on LAN addresses.
  composeOverride = pkgs.writeText "compose-vesta.yaml" ''
    networks:
      default:
        ipam:
          config:
            - subnet: 172.31.42.0/24
              gateway: 172.31.42.1

    services:
      nginx:
        ports: !override
          - "127.0.0.1:18080:80"
          - "127.0.0.1:8443:443"
        extra_hosts: !override
          - "host.docker.internal:172.31.42.1"

      mysql:
        ports: !override
          - "127.0.0.1:3306:3306"
      postgres:
        ports: !override
          - "127.0.0.1:5432:5432"
      valkey:
        ports: !override
          - "127.0.0.1:6379:6379"
      clickhouse:
        ports: !override
          - "127.0.0.1:8123:8123"
          - "127.0.0.1:9000:9000"

      floci:
        ports: !override
          - "127.0.0.1:4566:4566"
          - "172.31.42.1:4566:4566"
      auth:
        ports: !override
          - "127.0.0.1:4040:4040"
          - "172.31.42.1:4040:4040"
      crazyegg-core-v1:
        ports: !override
          - "127.0.0.1:3000:3000"
          - "172.31.42.1:3000:3000"
          - "127.0.0.1:9009:9009"
          - "172.31.42.1:9009:9009"
      events_api:
        ports: !override
          - "127.0.0.1:9796:9796"
          - "172.31.42.1:9796:9796"
      # A pre-existing container holds 127.0.0.1:4000; dev-nginx only needs
      # the gateway binding.
      video_api:
        ports: !override
          - "172.31.42.1:4000:4000"
      storage-api:
        ports: !override
          - "127.0.0.1:4044:3000"
          - "172.31.42.1:4044:3000"
      matrix-synapse:
        ports: !override
          - "127.0.0.1:8008:8008"
          - "172.31.42.1:8008:8008"
      keycloak:
        ports: !override
          - "127.0.0.1:8095:8080"
          - "172.31.42.1:8095:8080"
  '';

  # `scripts/server` hard-codes `-f docker-compose.yml`, so it cannot pick up
  # the override; this is the supported way to drive the stack on Vesta.
  crazyeggInfra = pkgs.writeShellApplication {
    name = "crazyegg-infra";
    text = ''
      repo="$HOME/develop/crazyegg/ce-local-infra"
      exec docker compose \
        --project-directory "$repo" \
        -p ce-local-infra \
        -f "$repo/docker-compose.yml" \
        -f ${composeOverride} \
        "$@"
    '';
  };
in
{
  home.packages = [ crazyeggInfra ];
  xdg.configFile."crazyegg/compose-vesta.yaml".source = composeOverride;
}
