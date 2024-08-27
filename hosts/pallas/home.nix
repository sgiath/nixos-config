{ pkgs, ... }:

{
  imports = [
    ../../work
  ];

  home.packages = [
    pkgs.lshw
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
    games.enable = false;
  };

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 12;
  };
}
