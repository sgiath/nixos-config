{ pkgs, ... }:
{
  imports = [ ../../work ];

  home.packages = with pkgs; [
    xfce.thunar
    obsidian
    webcord
    telegram-desktop
    signal-desktop-beta
    gimp
    yt-dlp

    vscodium-fhs

    betaflight-configurator
    bisq-desktop
    trezor-suite
    trezor-udev-rules
  ];

  programs = {
    chromium.enable = true;
    davinci.enable = true;
    firefox.enable = true;
    git.enable = true;
    gpg.enable = true;
    hyprland.enable = true;
    kitty.enable = true;
    nvim.enable = true;
    obs-studio.enable = false;
    ssh.enable = true;
    starship.enable = true;
    tmux.enable = true;
    waybar.enable = true;
    zsh.enable = true;
  };

  services = {
    ollama.enable = false;
  };

  sgiath = {
    enable = true;
    audio.enable = true;
    email_client.enable = true;
    games.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
