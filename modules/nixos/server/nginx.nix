{ pkgs, ... }:
{
  services.nginx = {
    package = pkgs.nginxQuic;
    eventsConfig = ''
      multi_accept on;
      worker_connections 2048;
    '';
    defaultListen = [
      { addr = "192.168.1.2"; }
      { addr = "192.168.1.3"; }
    ];
    resolver.addresses = [ "127.0.0.1:53" ];

    clientMaxBodySize = "128M";
    enableQuicBPF = true;
    mapHashBucketSize = 256;
    mapHashMaxSize = 4096;
    serverNamesHashBucketSize = 128;
    serverNamesHashMaxSize = 2048;
    statusPage = true;

    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedZstdSettings = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      charset utf-8;
      log_not_found off;
      aio threads;
      directio 4m;
      client_body_buffer_size 1K;
      client_header_buffer_size 1k;

      # allow the server to close connection on non responding client, this will free up memory
      reset_timedout_connection on;

      # if client stop responding, free up memory -- default 60
      send_timeout 20;
    '';
  };
}
