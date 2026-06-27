# NixOS configs

## Install

```bash
# install system config
nixos-rebuild switch --sudo --flake https://github.com/sgiath/nixos-config#ceres

reboot

# install dotfiles
git clone https://github.com/sgiath/nixos-config ~/nixos
cd nixos/
nixos-rebuild switch --sudo --flake '.#ceres'

reboot
```

## Usage

```bash
# update release pinned flake inputs and packages
./update-inputs

# update branch inputs
nix flake update

# switch current system
update

# switch server
update --vesta
```

## Useful fixes

Fonts not rendering anywhere

```bash
fc-cache -f -v
```

Proton Mail app not starting - run it once like this to migrate to Wayland

```bash
XDG_SESSION_TYPE=x11 proton-mail
```
