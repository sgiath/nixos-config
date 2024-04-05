{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    recommendedZstdSettings = true;
    virtualHosts.crazyeggdev = {
      addSSL = true;
      serverName = "crazyeggdev.com";
      serverAliases = [
        "*.crazyeggdev.com"
        "crazyeggproxydev.com"
        "*.crazyeggproxydev.com"
      ];
      sslCertificate = "/var/development.cert";
      sslCertificateKey = "/var/development.key";
      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "$target_destination";
        extraConfig = ''
          proxy_set_header CF-Connecting-IP $proxy_add_x_forwarded_for;
        '';
      };
    };
    appendHttpConfig = ''
      map $http_host $target_destination {
        hostnames;

        default 'http://127.0.0.1:3000';

        # Core v1, crazyegg
        app.crazyeggdev.com 'http://127.0.0.1:3000';
        demo.crazyeggdev.com 'http://127.0.0.1:3000';
        old-player.crazyeggdev.com 'http://127.0.0.1:3000';
        editor.crazyeggdev.com 'http://127.0.0.1:3000';

        # Core v2 marketing, ce/apps/w3_web
        crazyeggdev.com 'http://127.0.0.1:4004';
        www.crazyeggdev.com 'http://127.0.0.1:4004';

        # Core v2 backend, ce/apps/app_web
        api.crazyeggdev.com 'http://127.0.0.1:4001';

        # Admin v2, ce/apps/admin_web
        admin.app.crazyeggdev.com 'http://127.0.0.1:4005';

        # Metrex, ce/apps/metrex
        metrics.crazyeggdev.com 'http://127.0.0.1:4007';

        # Auth service
        auth.app.crazyeggdev.com 'http://127.0.0.1:4040';

        # Core v2 shell, shell
        core.crazyeggdev.com 'http://127.0.0.1:8080';
        share.crazyeggdev.com 'http://127.0.0.1:8080';

        # Mocky Frontend, mocky-frontend
        script.mocky.crazyeggdev.com 'http://127.0.0.1:8081';

        # HUD
        hud.crazyeggdev.com 'http://127.0.0.1:8082';

        # Mocky Backend, mocky-backend
        mocky.crazyeggdev.com 'http://127.0.0.1:4000';

        # Flow Tracking, crazyegg, not sure how to run or if it's in use
        ftrk.crazyeggdev.com 'http://127.0.0.1:3001';

        # Old HUD signup, hud-signup
        powerup.crazyeggdev.com 'http://127.0.0.1:3003';

        # Old Insights, insights
        insights.crazyeggdev.com 'http://127.0.0.1:3030';

        # Integration API, ce3/apps/integration_api
        integration-api.crazyeggdev.com 'http://127.0.0.1:4002';

        # SSO Accounts proxy, accounts
        accounts.crazyeggdev.com 'http://127.0.0.1:4202';

        # Old Internal Metrics, global-metrics-system, in conflict with interagent. Not used anymore?
        # info.crazyeggdev.com 'http://127.0.0.1:9009';

        # Core v1 ember editor, crazyegg/apps/web-editor
        ember-editor.app.crazyeggdev.com 'https://localhost:4300';

        # Core v1 ember shell, crazyegg/apps/shell
        ember-shell.app.crazyeggdev.com 'https://localhost:4200';

        # tracking-api
        tracking.crazyeggdev.com 'http://127.0.0.1:9596';

        # user-script-api
        script.crazyeggdev.com 'http://127.0.0.1:9292';

        # localstack
        localstack.crazyeggdev.com 'http://127.0.0.1:4566';

        # video-api
        player.crazyeggdev.com 'http://127.0.0.1:4000';

        # zaraz
        zaraz.crazyeggdev.com 'http://127.0.0.1:1337';

        # Interagent proxy, crazyegg/apps/go
        crazyeggproxydev.com 'http://127.0.0.1:9009';

        oauth.crazyeggdev.com 'http://127.0.0.1:4008';

        resthooks.crazyeggdev.com 'http://127.0.0.1:4009';

        # Snapshot report app
        snapshot.crazyeggdev.com 'http://127.0.0.1:8083';

        # ai-crazy app
        ai.crazyeggdev.com 'http://127.0.0.1:4042';

        # crazyegg-channels app
        channels.crazyeggdev.com 'http://127.0.0.1:4043';
      }
    '';
  };
}
