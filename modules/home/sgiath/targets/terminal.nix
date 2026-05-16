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
      usbutils
      iputils
      lsof
      mprocs
      presenterm
      rclone
      jq
      # pkgs.${namespace}.nak
      # pkgs.${namespace}.relay-tester

      openssl
      yt-dlp
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
      neovim.enable = true;
      ssh.enable = true;
      starship.enable = true;
      tmux.enable = true;
      yazi = {
        enable = true;
        shellWrapperName = "y";
      };
      zsh.enable = true;
      ripgrep.enable = true;

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
