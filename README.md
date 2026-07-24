# NixOS Configuration

Configuración personal de NixOS basada en **flakes**, con Hyprland y Niri como
compositores Wayland. Dos máquinas x86_64 (`hades` portátil, `korriban` server)
más una Raspberry Pi 3.

Release actual: **NixOS 26.05**.

## 📁 Estructura

Cada host es un output explícito del flake. No hay dispatcher ni `if` por
hostname: `hosts/<host>/default.nix` declara qué módulos usa cada máquina.
Nada de escritorio en el server; nada de server en el portátil.

```
.
├── flake.nix / flake.lock     # Raíz: inputs pineados y nixosConfigurations
├── lib/mkHost.nix             # Helper que arma cada host (evita duplicación)
├── hosts/
│   ├── hades/                 #   portátil → common + desktop + media + gpu-nvidia
│   │   ├── default.nix
│   │   └── hardware.nix       #   hardware EN EL REPO (obligatorio con flakes)
│   ├── korriban/              #   server headless → common + server + media + gpu-amd + sail
│   │   ├── default.nix
│   │   └── hardware.nix
│   └── default.nix            #   plantilla mínima para una máquina nueva
├── modules/                   # Bloques reutilizables, sin dependencias implícitas
│   ├── common.nix             #   base para TODAS: red, SSH, zsh, git, nix, CLI
│   ├── desktop.nix            #   Wayland (Hyprland/Niri, SDDM, audio, GUI)
│   ├── server.nix             #   homelab: AdGuard, Caddy, homepage-dashboard
│   ├── media.nix              #   Jellyfin, Transmission, MiniDLNA
│   ├── sail.nix               #   LakeSail (Spark Connect + Arrow Flight SQL)
│   ├── gpu-amd.nix            #   drivers AMD (VAAPI, transcoding)
│   └── gpu-nvidia.nix         #   drivers NVIDIA + PRIME
├── assets/                    # Imágenes versionadas (wallpapers, avatar de SDDM)
├── scripts/
│   └── check-dotfiles.sh      # Detecta enlaces muertos en los dotfiles
├── docs/migracion-flakes.md   # Plan y decisiones de la migración a flakes
├── rpi3/                      # Raspberry Pi 3 (flake propio, aarch64, 25.11)
├── flakes/sail/               # Devshells de desarrollo (pin propio)
└── dotfiles/                  # Dotfiles gestionados con GNU Stow
    ├── hypr/  niri/           # Compositores
    ├── waybar/ rofi/ swaync/  # Barra, launcher, notificaciones
    ├── kitty/ yazi/           # Terminal, gestor de ficheros
    ├── wlogout/ nixpkgs/
    └── bin/                   # Scripts personalizados (→ ~/bin)
```

**Por qué el hardware está en el repo:** en evaluación pura un flake no puede
leer `/etc/nixos/hardware-configuration.nix` (ruta absoluta fuera del árbol).
Sin él haría falta `--impure` en cada rebuild, perdiendo la reproducibilidad.
Solo contiene UUIDs de particiones y módulos de kernel.

## 🚀 Instalación

### 1. Clonar

```bash
git clone git@github.com:davidlghellin/nix-os.git ~/nix-os
cd ~/nix-os
```

### 2. Añadir el hardware de la máquina

```bash
sudo cp /etc/nixos/hardware-configuration.nix hosts/<host>/hardware.nix
git add hosts/<host>/hardware.nix     # el flake solo ve ficheros trackeados
```

### 3. Construir sin activar, y luego aplicar

```bash
nixos-rebuild build --flake .#<host>              # no toca el sistema
nix store diff-closures /run/current-system ./result   # revisar qué cambia
sudo nixos-rebuild switch --flake .#<host>
```

### 4. Dotfiles con Stow

```bash
cd ~/nix-os/dotfiles
for d in */; do stow -v -t ~ "$d"; done
```

Existen los alias `dots-apply` y `dots-restore` para esto.

> No hace falta copiar ningún `.zshrc`: la configuración de Zsh es declarativa
> y vive en `modules/common.nix` (`programs.zsh`).

**Máquina nueva:** crea `hosts/<nombre>/` con su `default.nix` (lista de módulos)
y su `hardware.nix`, y añade una línea en `flake.nix`. Nada más.

## 🔧 Uso diario

```bash
nrs           # rebuild + switch del host actual, con nix-output-monitor
nrs-notify    # igual, pero avisa al terminar (notificación + sonido)
```

Ambos resuelven el host desde el hostname en minúsculas (`Korriban` → `korriban`).

### Actualizar paquetes

```bash
nix flake update              # todos los inputs
nix flake update nixpkgs      # solo uno
nrs
```

El `flake.lock` queda como diff revisable: se revierte con `git revert`.

### Subir de release

Cambiar la rama en el input de `flake.nix` (p. ej. `nixos-26.05` → `nixos-26.11`),
`nix flake update nixpkgs`, y **construir antes de activar**. `system.stateVersion`
NO se toca nunca: indica con qué versión se instaló la máquina, no la que usa.

### Verificar los dotfiles

```bash
./scripts/check-dotfiles.sh
```

Comprueba que los binarios invocados existan, que Niri no use herramientas de
Hyprland (`hyprctl`/`hyprshot`), que no haya rutas `/nix/store/...` escritas a
mano, que las rutas referenciadas existan, y valida la sintaxis (`niri validate`,
JSONC de waybar, `bash -n`, `hyprctl configerrors`). Útil antes de commitear.

### Recargar configuración sin rebuild

Los dotfiles van por stow, así que los cambios ya están en su sitio:

```bash
hyprctl reload          # Hyprland
niri msg reload-config  # Niri
```

## 🖥️ Máquinas

| | hades | korriban | rpi3 |
|---|---|---|---|
| Rol | portátil con escritorio | server headless | homelab pequeño |
| Hardware | ASUS TUF F15, i5-11400H, NVIDIA | AMD | Raspberry Pi 3 (aarch64) |
| Release | 26.05 | 26.05 | 25.11 (flake aparte) |
| Servicios | — | AdGuard, Caddy, Jellyfin, Transmission, MiniDLNA, Sail | AdGuard, MiniDLNA |

## ⚙️ Características

- **Boot**: systemd-boot, límite de 5 generaciones en el menú
- **Garbage collection**: automático semanal, `--delete-older-than 30d`
- **Deduplicación del store**: `nix.optimise` semanal + `auto-optimise-store`
  incremental. GC de emergencia si bajan de 5 GiB libres (`min-free`)
- **Coredumps acotados**: 2G por proceso, 4G de tope total
- **Paquetes de unstable**: vía overlay `pkgs.unstable.*`, pineado en `flake.lock`

### Escritorio

- **Compositores**: Hyprland y Niri
- **Login**: SDDM (Wayland, compositor `kwin`, tema `pixie`)
- **Terminal**: Kitty · **Shell**: Zsh (declarativo) · **Launcher**: Rofi
- **Barra**: Waybar (tema `left`, vertical) · **Notificaciones**: SwayNC
- **Lock**: Hyprlock · **Wallpapers**: `awww` + `selector-wallpaper`
- **Capturas**: Hyprshot en Hyprland; acciones nativas en Niri
  (`hyprshot` depende de `hyprctl` y no funciona bajo Niri)

### Monitores

- **eDP-1** (portátil): 1920x1080 @ 144Hz
- **HDMI-A-1** (externo): 2560x1080 @ 60Hz, colocado arriba

## ⌨️ Keybindings principales

`Super` es la tecla modificadora en ambos compositores.

| Atajo | Acción |
|---|---|
| `Super + Return` | Terminal (kitty) |
| `Super + Space` | Rofi — launcher (en Niri: `Super + D`) |
| `Super + E` | Gestor de ficheros (thunar) |
| `Super + C` | Cerrar ventana |
| `Super + F` | Fullscreen |
| `Super + L` | Bloquear pantalla |
| `Super + M` | Salir de la sesión |
| `Super + F1` | Ayuda de atajos |
| `Super + P` / `Super + J` | Pseudotile / togglesplit (dwindle) |
| `F12` | Terminal desplegable (**solo Hyprland**: usa special workspaces) |
| `Print` / `Shift + Print` | Captura de ventana / de región |
| `Fn + F5` | Perfil de ventilación (`quiet`/`balanced`/`performance`) |

> El perfil de ventilación **persiste entre reinicios** porque lo guarda el EC.
> Si oyes el ventilador sin motivo: `cat /sys/firmware/acpi/platform_profile`.

## 🛠️ Scripts

En `~/bin/` (enlazados con stow desde `dotfiles/bin/bin/`):

- `selector-wallpaper` → selector con Rofi; busca en `assets/` del repo y en `~/Images`
- `show-keybindings` / `show-keybindings-niri` → ayuda de atajos
- `wlogout-custom` → menú de apagado

## 🩺 Diagnóstico

```bash
nixos-version --configuration-revision   # de qué commit viene el sistema
nix store diff-closures /run/current-system ./result
systemctl --failed
hyprctl configerrors
niri validate -c ~/.config/niri/config.kdl
sudo nix store optimise                  # deduplicar el store a mano
sudo nix store gc                         # borrar rutas inalcanzables
```

Volver atrás: elegir una generación anterior en el menú de arranque, o
`sudo nixos-rebuild --rollback`.

## 🔗 Enlaces útiles

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Hyprland Wiki](https://wiki.hypr.land/)
- [Niri Wiki](https://github.com/YaLTeR/niri/wiki)
- [GNU Stow](https://www.gnu.org/software/stow/)
