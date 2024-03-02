# NixOS configs

## Install

```bash
nix-shell -p git --command "git clone https://git.sr.ht/~sgiath/nix-config ~/.dotfiles"
sudo nixos-rebuild switch --flake ~/.dotfiles
nix run home-manager/master --extra-experimental-features nix-command --extra-experimental-features flakes -- switch --flake ~/.dotfiles
```
