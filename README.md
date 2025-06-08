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

## Useful fixes

Fonts not rendering anywhere
```bash
fc-cache -f -v
```

Proton Mail app not starting run it once like this to migrate to Wayland
```bash
XDG_SESSION_TYPE=x11 proton-mail
```
