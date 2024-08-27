{
  imports = [
    ./audio.nix
    ./browser.nix
    ./davinci.nix
    ./email_client.nix
    ./games.nix
    ./hyprland.nix
    ./kitty.nix
    ./ollama.nix
    ./waybar.nix

    # always enabled
    ./git.nix
    ./gnupg.nix
    ./nvim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./zsh.nix
  ];
}
