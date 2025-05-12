# NixOS configs

## Install

```bash
# install system config
sudo nixos-rebuild switch --flake https://git.sr.ht/~sgiath/nix-config#ceres

reboot

# install dotfiles
git clone https://git.sr.ht/~sgiath/nix-config ~/nixos
cd nixos/
sudo nixos-rebuild switch --flake .

reboot
upgrade
```
