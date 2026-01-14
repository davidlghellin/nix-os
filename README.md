# nix-os

## Ficheros
En este caso los ficheros son copiados manualmente, ya sea script o manual

Tenemos:
- /etc/nixos/configuration.nix
- /etc/nixos/hardware-configuration.nix

- ~/.config/hypr
- ~/.config/hypr/hypridle.conf
- ~/.config/hypr/hyprland.conf
- ~/.config/hypr/hyprlock.conf
- ~/.config/waybar
- ~/.config/kitty/kitty.conf

- ~/.config/radiotray-ng/bookmarks.json

- ~/.zshrc

```sh
cp -R ~/.config/waybar .
cp -R ~/.config/hypr .
cp -R ~/.config/kitty .
cp -R ~/.config/niri .
cp -R ~/.config/radiotray-ng .
cp -R ~/bin/selector-wallpaper .
sudo cp /etc/nixos/configuration.nix .
```
