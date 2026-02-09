# NixOS Configuration

Configuración personal de NixOS con Hyprland y Niri como gestores de ventanas.

## 📁 Estructura

```
.
├── configuration.nix          # Configuración principal de NixOS
├── hardware-configuration.nix # Configuración de hardware
├── .zshrc                     # Configuración de Zsh
└── dotfiles/                  # Dotfiles gestionados con GNU Stow
    ├── hypr/                  # Hyprland (compositor Wayland)
    ├── niri/                  # Niri (compositor alternativo)
    ├── rofi/                  # Launcher de aplicaciones
    ├── swaync/                # Centro de notificaciones
    ├── waybar/                # Barra de estado
    ├── kitty/                 # Emulador de terminal
    └── bin/                   # Scripts personalizados
```

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone git@github.com:davidlghellin/nix-os.git ~/nix-os
cd ~/nix-os
```

### 2. Instalar configuración del sistema

```bash
sudo cp configuration.nix /etc/nixos/
sudo nixos-rebuild switch
```

### 3. Aplicar dotfiles con Stow

```bash
cd ~/nix-os/dotfiles
stow hypr
stow niri
stow rofi
stow swaync
stow waybar
stow kitty
stow bin
```

### 4. Configurar Zsh

```bash
cp ~/nix-os/.zshrc ~/
source ~/.zshrc
```

## ⚙️ Características

### Sistema
- **OS**: NixOS
- **Gestores de ventanas**: Hyprland + Niri (Wayland)
- **Boot**: systemd-boot (límite 5 generaciones)
- **Garbage Collection**: Automático semanal (7 días)

### Entorno de escritorio
- **Terminal**: Kitty
- **Shell**: Zsh
- **Launcher**: Rofi
- **Notificaciones**: SwayNC
- **Barra**: Waybar
- **Lock screen**: Hyprlock
- **Screenshots**: Hyprshot → `~/Images`
- **Wallpapers**: pywal (wal)

### Monitores
- **eDP-1** (laptop): 1920x1080 @ 144Hz
- **HDMI-A-1** (externo): 2560x1080 @ 60Hz (arriba)

## ⌨️ Keybindings principales

### Hyprland / Niri (similares)
- `Super + Return` → Terminal
- `Super + Space` → Rofi (launcher)
- `Super + C` → Cerrar ventana
- `Super + F` → Fullscreen (Hyprland)
- `Super + F1` → Mostrar ayuda de teclas
- `Super + L` → Lock screen
- `Super + M` → Salir (Hyprland)
- `Print` → Screenshot ventana
- `Shift + Print` → Screenshot región

## 🛠️ Scripts personalizados

Scripts en `~/bin/` (gestionados con stow):
- `selector-wallpaper` → Selector de wallpapers con Rofi
- `show-keybindings` → Muestra ayuda de teclas
- `programa` → Script de utilidad

## 🔧 Mantenimiento

### Actualizar el sistema
```bash
sudo nixos-rebuild switch
```

### Actualizar dotfiles
Los dotfiles están enlazados con stow, así que cualquier cambio en `~/nix-os/dotfiles/` se refleja automáticamente.

### Limpieza manual de generaciones
```bash
# Ver generaciones
nix-env --list-generations

# Limpiar generaciones antiguas (automático cada semana)
nix-collect-garbage --delete-older-than 7d
```

## 📦 Paquetes principales

Ver lista completa en `configuration.nix`, incluye:
- hyprland, niri
- kitty, rofi, waybar, swaync
- firefox, git, vim
- pywal, hyprshot
- y más...

## 🔗 Enlaces útiles

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Niri Wiki](https://github.com/YaLTeR/niri/wiki)
- [GNU Stow](https://www.gnu.org/software/stow/)
