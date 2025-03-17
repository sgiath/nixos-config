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
      superfile
      yt-dlp
      parted
      google-cloud-sdk
      nix-du
      exfat
      p7zip
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
    };

    services = {
      podman.enable = true;
    };
  };
}
