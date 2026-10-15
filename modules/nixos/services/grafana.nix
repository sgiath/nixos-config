{
  config,
  lib,
  ...
}:
let
  nebula = config.sgiath.nebula;
  host = "grafana.sgiath.dev";
  port = 3000;
  user = "sgiath";
in
{
  # Grafana itself; data sources and dashboards come from the modules that own
  # the data (agent-archive.nix). Nebula is the auth: nginx signs every request
  # in as the admin through Grafana's auth proxy, so there is no login.
  # (Anonymous access would do the same, but Grafana 13 limits it to viewers,
  # which cannot use Explore or edit dashboards.)
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "grafana" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.grafana.enable) {
      sops.secrets.grafana_secret_key = {
        sopsFile = ../../../secrets/vesta.yaml;
        owner = "grafana";
        restartUnits = [ "grafana.service" ];
      };

      services.grafana.settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = port;
          domain = host;
          root_url = "https://${host}";
        };
        security = {
          secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
          admin_user = user;
        };
        auth.disable_login_form = true;
        "auth.basic".enabled = false;
        "auth.proxy" = {
          enabled = true;
          header_name = "X-WEBAUTH-USER";
          header_property = "username";
          auto_sign_up = true;
          whitelist = "127.0.0.1, ::1";
        };
        users = {
          allow_sign_up = false;
          auto_assign_org_role = "Admin";
        };
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };
        news.news_feed_enabled = false;
      };

      services.nginx.virtualHosts.${host} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay only
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          deny all;
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          extraConfig = "proxy_set_header X-WEBAUTH-USER ${user};";
        };
      };
    })
  ];
}
