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
      yt-dlp
      parted
      google-cloud-sdk

    ];

    programs = {
      git.enable = true;
      gpg.enable = true;
      nvim.enable = true;
      ssh.enable = true;
      starship.enable = true;
      tmux.enable = true;
      zsh.enable = true;

      # docs
      texlive = {
        enable = true;
        package = pkgs.texliveMedium;
      };
      pandoc.enable = true;
    };
  };
}
