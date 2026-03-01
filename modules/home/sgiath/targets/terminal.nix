{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
{
  options.sgiath.targets.terminal = lib.mkEnableOption "terminal target";

  config = lib.mkIf (config.sgiath.targets.terminal) {
    home.packages = with pkgs; [
      coreutils-prefixed
      mprocs
      presenterm
      rclone
      jq
      pkgs.${namespace}.nak
      pkgs.${namespace}.relay-tester

      openssl
      yt-dlp
      google-cloud-sdk
      railway

      exiftool
      multitail

      gnumake
    ];

    sgiath = {
      agents.enable = true;
    };

    programs = {
      git.enable = true;
      gpg.enable = true;
      nvim.enable = true;
      ssh.enable = true;
      starship.enable = true;
      tmux.enable = true;
      yazi.enable = true;
      zsh.enable = true;

      # install zed-server even in terminal environment
      zed-editor = {
        enable = true;
        installRemoteServer = true;
      };
    };

    services = {
      podman.enable = true;

      stunnel = {
        enable = true;
        clients = {
          horizons = {
            accept = "127.0.0.1:6775";
            connect = "ssd.jpl.nasa.gov:6770";
            socket = [
              "l:TCP_NODELAY=1"
              "l:TCP_NODELAY=1"
            ];
            sslVersion = "all";
            TIMEOUTclose = "0";
          };
        };
      };
    };
  };
}
