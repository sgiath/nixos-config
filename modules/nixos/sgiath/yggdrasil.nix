{ lib, config, ... }:
{
  config = lib.mkIf config.services.yggdrasil.enable {
    services.yggdrasil = {
      openMulticastPort = true;
      persistentKeys = true;
      settings = {
        Listen = [
          "quic://0.0.0.0:56088"
          "quic://[::]:56088"
        ];

        # https://publicpeers.neilalexander.dev/
        Peers = [
          # czechia
          "tls://[2a03:3b40:fe:ab::1]:993"
          "tls://37.205.14.171:993"

          # slovakia
          "tcp://y.zbin.eu:7743"
          "quic://ygg-ke.8px.sk:4321"
        ]
        ++ lib.optionals (config.networking.hostName == "ceres") [
          "quic://192.168.1.2:56088"
          "quic://192.168.1.3:56088"
        ];
      };
    };
  };
}
