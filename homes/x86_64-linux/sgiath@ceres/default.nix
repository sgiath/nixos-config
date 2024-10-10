{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xfce.thunar
    obsidian
    gimp
    vscodium-fhs

    webcord
    telegram-desktop
    signal-desktop-beta
    cinny-desktop
    simplex-chat-desktop

    yt-dlp
    parted

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

  sgiath = {
    enable = true;
    audio.enable = true;
    email_client.enable = true;
    games.enable = true;
  };

  crazyegg.enable = true;

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
