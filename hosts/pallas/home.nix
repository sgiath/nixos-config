{ pkgs, ... }:
{
  imports = [ ../../work ];

  home.packages = with pkgs; [
    xfce.thunar
    obsidian
    webcord
    telegram-desktop
    signal-desktop-beta
  ];

  programs = {
    chromium.enable = true;
    davinci.enable = false;
    firefox.enable = true;
    git.enable = true;
    gpg.enable = true;
    hyprland.enable = true;
    kitty.enable = true;
    nvim.enable = true;
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
    games.enable = false;
  };

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 12;
  };
}
