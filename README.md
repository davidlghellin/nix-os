# NixOS Configuration

Configuración personal de NixOS con Hyprland y Niri como gestores de ventanas.

## 📁 Estructura

```
.
├── configuration.nix          # Configuración principal de NixOS
├── hardware-configuration.nix # Configuración de hardware
├── nvidia.nix                 # Configuración NVIDIA (opcional)
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

**IMPORTANTE**: Ejecutar stow desde `~/nix-os` (no desde `~/nix-os/dotfiles`)

```bash
cd ~/nix-os
stow -d dotfiles -t ~ hypr
stow -d dotfiles -t ~ niri
stow -d dotfiles -t ~ rofi
stow -d dotfiles -t ~ swaync
stow -d dotfiles -t ~ waybar
stow -d dotfiles -t ~ kitty
stow -d dotfiles -t ~ bin
```

O todos a la vez:
```bash
cd ~/nix-os
for dir in dotfiles/*/; do stow -d dotfiles -t ~ "$(basename "$dir")"; done
```

### 4. Configurar Zsh

```bash
cp ~/nix-os/.zshrc ~/
source ~/.zshrc
```

## ⚠️ NVIDIA (Importante)

La configuración de NVIDIA está separada en `nvidia.nix` para poder reutilizar la configuración en ordenadores con o sin NVIDIA.

**En portátiles CON NVIDIA** (como hades):
```nix
imports = [
  ./hardware-configuration.nix
  ./nvidia.nix  # Activo
];
```

**En portátiles SIN NVIDIA**:
```nix
imports = [
  ./hardware-configuration.nix
  # ./nvidia.nix  # Comentar esta línea
];
```

**Nota**: Los `intelBusId` y `nvidiaBusId` en `nvidia.nix` son específicos de cada máquina. Para encontrar los IDs correctos:
```bash
lspci | grep -E "VGA|3D"
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
- **Launcher**: Rofi (consistente en Hyprland y Niri)
- **Notificaciones**: SwayNC
- **Barra**: Waybar
- **Lock screen**: Hyprlock
- **Screenshots**: Hyprshot → `~/Images/Screenshots` (consistente en ambos WM)
- **Wallpapers**: pywal (wal)

**Nota**: Hyprland y Niri están configurados de forma consistente - mismo launcher (rofi), mismas capturas (hyprshot), mismo autostart, para una experiencia uniforme al cambiar entre ambos.

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
- `show-keybindings` → Muestra ayuda de teclas (Hyprland)
- `show-keybindings-niri` → Muestra ayuda de teclas (Niri)
- `programa` → Script de utilidad

## 🔧 Mantenimiento

### Actualizar el sistema
```bash
sudo nixos-rebuild switch
```

### Actualizar dotfiles
Los dotfiles están enlazados con stow, así que cualquier cambio en `~/nix-os/dotfiles/` se refleja automáticamente.

Para reenlazar (restow) si es necesario:
```bash
cd ~/nix-os
stow -R -d dotfiles -t ~ <nombre-paquete>  # Reenlazar un paquete específico
```

Para recargar la configuración:
```bash
hyprctl reload          # En Hyprland
niri msg reload-config  # En Niri
```

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
