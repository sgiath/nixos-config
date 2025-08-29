{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.targets.terminal = lib.mkEnableOption "terminal target";

  config = lib.mkIf (config.sgiath.targets.terminal) {
    home.packages = with pkgs; [
      coreutils-prefixed
      mprocs
      presenterm

      openssl
      # codex
      # opencode
      # gemini-cli

      yt-dlp
      google-cloud-sdk

      exiftool
      multitail

      gnumake
    ];

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
    };
  };
}
