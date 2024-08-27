{ pkgs, ... }:

{
  imports = [
    ../../home-manager

    # CrazyEgg
    ../../work
  ];

  home.packages = [
    pkgs.betaflight-configurator
    pkgs.bisq-desktop
    pkgs.trezor-suite
    pkgs.trezor-udev-rules
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
    ssh.enable = true;
    starship.enable = true;
    tmux.enable = true;
    waybar.enable = true;
  };

  services = {
    ollama.enable = false;
  };

  sgiath = {
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
