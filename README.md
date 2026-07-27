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
├── lib/
│   ├── mkHost.nix             # Helper que arma cada host (evita duplicación)
│   └── mkUser.nix             # Usuario "normal" sin sudo (equipo para otra persona)
├── hosts/
│   ├── hades/                 #   portátil → common + desktop + media + gpu-nvidia
│   │   ├── default.nix
│   │   └── hardware.nix       #   hardware EN EL REPO (obligatorio con flakes)
│   ├── korriban/              #   server headless → common + server + media + gpu-amd + sail
│   │   ├── default.nix
│   │   └── hardware.nix
│   └── default.nix            #   PLANTILLA para una máquina nueva (nadie la importa)
├── modules/                   # Bloques reutilizables, sin dependencias implícitas
│   ├── common.nix             #   base para TODAS: red, SSH, zsh, git, nix, CLI
│   ├── desktop.nix            #   Wayland (Hyprland/Niri, SDDM, audio, GUI)
│   ├── server.nix             #   homelab: AdGuard, Caddy, homepage-dashboard
│   ├── media.nix              #   Jellyfin, Transmission, MiniDLNA
│   ├── sail.nix               #   LakeSail (Spark Connect + Arrow Flight SQL)
│   ├── gpu-amd.nix            #   drivers AMD (VAAPI, transcoding)
│   └── gpu-nvidia.nix         #   drivers NVIDIA + PRIME
├── assets/                    # Imágenes versionadas (wallpapers, avatar de SDDM).
│                              #   desktop.nix las instala en /etc/wallpapers
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

### 0. Instalar NixOS de la forma normal

Este repo no se autoinstala: necesita un sistema ya arrancado y `git` para
clonarlo. Así que primero, instalación normal desde el ISO.

**Qué usuario crear en el instalador: `wizord`.** No es un capricho — es el que
declara `modules/common.nix`, y con `users.mutableUsers = true` (el valor por
defecto, aquí no se cambia) la contraseña que le pongas en la instalación es la
que se queda. Si creases solo el usuario de otra persona, tras el primer switch
`wizord` existiría **sin contraseña** (no podrías entrar) y el otro usuario no
tendría `wheel`, o sea que tampoco podría lanzar el rebuild. Los usuarios extra
se añaden después, declarativamente (ver `lib/mkUser.nix` más abajo).

Elige la versión del ISO a conciencia: es la que va en `stateVersion`.

### 1. Clonar

```bash
nix-shell -p git      # si el sistema recién instalado no trae git
git clone https://github.com/davidlghellin/nix-os.git ~/nix-os
cd ~/nix-os
```

Por HTTPS y no por SSH: en una máquina nueva todavía no hay clave subida a
GitHub. El remoto se cambia a SSH luego, cuando la haya.

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

No hace falta activar flakes a mano antes del primer switch: aunque
`nix.settings.experimental-features` de este repo no está aplicado todavía,
`nixos-rebuild` se los pasa a `nix` por su cuenta cuando ve `--flake`
(`FLAKE_FLAGS` en nixos-rebuild-ng).

### 4. Dotfiles con Stow

```bash
cd ~/nix-os/dotfiles
for d in */; do stow -v -t ~ "$d"; done
```

Existen los alias `dots-apply` y `dots-restore` para esto.

> No hace falta copiar ningún `.zshrc`: la configuración de Zsh es declarativa
> y vive en `modules/common.nix` (`programs.zsh`).

### 5. Comprobar que no quedó nada roto

```bash
./scripts/check-dotfiles.sh
```

Verifica lo que no da error por sí solo: binarios que los dotfiles invocan y no
existen, rutas del store escritas a mano, rutas atadas a un `/home/<usuario>`
concreto, familias de fuente no instaladas (fontconfig cae en otra en silencio)
y la sintaxis de cada config. Sale 0 si todo está bien.

**Máquina nueva:** copia la plantilla `hosts/default.nix` a
`hosts/<nombre>/default.nix`, descomenta los módulos que use, pon su
`hostName` y su `stateVersion`, añade el `hardware.nix` y una línea en
`flake.nix`. Los pasos están en la cabecera de la propia plantilla.

**Usuario nuevo:** `wizord` lo declara `modules/common.nix`, que lo importan
todos los hosts, así que es admin (`wheel` → sudo) en cualquier máquina sin
tocar nada. Para añadir a otra persona encima —un equipo que montas para
alguien, pero al que quieres poder entrar a arreglar cosas— hay
`lib/mkUser.nix`:

```nix
imports = [
  ../../modules/common.nix
  ../../modules/desktop.nix
  (import ../../lib/mkUser.nix {
    nombre = "david";
    descripcion = "David";
    paquetes = p: [ p.firefox p.vlc ];   # solo para él, no para el sistema
  })
];
```

La contraseña no va en el repo: nace bloqueado hasta que hagas `sudo passwd
david` tras el primer switch. Si va a usar el escritorio, los dotfiles se le
aplican entrando como él y lanzando `dots-apply`.

**Dos tipos de usuario**, según si además administra la máquina:

| | grupos que recibe |
|---|---|
| por defecto (`admin = false`) | `networkmanager` + los de la sesión gráfica |
| `admin = true` | los de arriba **+ `wheel` (sudo) + `storage` + `plugdev`** |

Y hay `escritorio = false` (para una máquina sin pantalla) y `red = false` (no
le deja tocar la wifi). Con todo en `false` se queda sin ningún grupo extra.

### Dónde poner los paquetes

**`environment.systemPackages` no es "de wizord": es del sistema.** Es un
malentendido fácil, porque el fichero donde está es el mismo donde se declara
`wizord` — pero `wizord.packages` está literalmente vacío (`[]`). Los ~300
paquetes van a `/run/current-system/sw/bin`, que lo ve **cualquier usuario** de
la máquina, incluido el nuevo y root.

| Quieres que… | Va en |
|---|---|
| lo tenga todo el mundo (**el caso normal**) | `environment.systemPackages` de `modules/common.nix` (CLI) o `modules/desktop.nix` (GUI) |
| lo tenga solo un usuario | `paquetes` de `mkUser.nix` → `users.users.<n>.packages`, su perfil |

O sea que **no**: para que algo esté para todos no hay que tocar nada de
wizord. Al añadir en cualquiera de los dos sitios, `nrs`.

Y **no se repite nada en ningún caso**. Ni siquiera cuando un conjunto es para
varios usuarios pero no para todo el sistema: se define una vez en un `let` y
se reutiliza. Ejemplo de portátil con tres usuarios separados:

```nix
{ ... }:
let
  ofimatica = p: [ p.libreoffice-fresh p.firefox ];   # definido UNA vez
in
{
  imports = [
    ./hardware.nix
    ../../modules/common.nix       # los ~300 paquetes: los ven los tres
    ../../modules/desktop.nix

    (import ../../lib/mkUser.nix { nombre = "ana";  paquetes = ofimatica; })
    (import ../../lib/mkUser.nix { nombre = "luis"; paquetes = p: ofimatica p ++ [ p.gimp ]; })
    (import ../../lib/mkUser.nix { nombre = "nano"; admin = true; })
  ];
}
```

> **No hay coste en disco por elegir mal.** Aunque tres usuarios tengan el
> mismo paquete en su perfil, es la *misma* ruta del store: el perfil solo
> añade symlinks. Sistema vs perfil de usuario es una decisión de **quién lo
> ve**, no de cuánto ocupa.

Ojo con lo que significa "separados": lo que separa a los usuarios son sus
homes, sus sesiones y sus perfiles de navegador. Que compartan los programas no
va en contra de eso — al revés, es lo que hace que se actualicen en un solo
sitio.

### Si un usuario quiere instalarse algo él mismo

No necesita sudo ni tocar el repo. Cada usuario tiene su propio perfil:

```bash
nix profile add nixpkgs#vlc     # se lo instala a él, sin sudo
nix profile list                # ver lo que lleva instalado
nix profile remove vlc          # quitarlo
nix profile upgrade --all       # actualizar lo suyo
nix shell nixpkgs#vlc           # solo para usarlo un rato, no instala nada
```

> `add`, no `install`: en Nix 2.34 `install` sigue funcionando pero avisa de que
> es un alias deprecado.

**`nixpkgs#` no se le va a desincronizar del sistema**, y no es casualidad:
`nix.registry.nixpkgs.flake` (en `common.nix`) apunta el registry al mismo
nixpkgs pineado del `flake.lock`, así que instala la misma versión que corre la
máquina. Sin eso, `nixpkgs#` iría a `nixpkgs-unstable` del canal público.

Dos límites que conviene saber:

- **Es imperativo.** No queda en el repo, así que no sobrevive a una
  reinstalación ni aparece en otra máquina. Si es algo que quiere para siempre,
  mejor pedírtelo y que entre en `paquetes` o en `systemPackages`.
- **Los paquetes unfree le fallarán.** `nixpkgs.config.allowUnfree` es de la
  config del sistema y no se aplica a un `nix profile install` de usuario.
  Tendría que ser `NIXPKGS_ALLOW_UNFREE=1 nix profile install --impure
  nixpkgs#loquesea`, y para unfree es más limpio que lo declares tú.

## 🔧 Uso diario

```bash
nrs           # rebuild + switch del host actual, con nix-output-monitor
nrs-notify    # igual, pero avisa al terminar (notificación + sonido)
```

Ambos resuelven el host desde el hostname en minúsculas (`Korriban` → `korriban`).

## 🔄 Actualizar

Tres niveles, de menor a mayor impacto. En todos, el `flake.lock` queda como
un diff revisable y reversible.

### 1. Paquetes del release actual (lo habitual)

```bash
nix flake update nixpkgs      # avanza dentro de la rama nixos-26.05
nrs
```

Trae parches de seguridad y correcciones sin cambiar de release. Bajo riesgo.

### 2. Solo los paquetes de unstable

```bash
nix flake update nixpkgs-unstable
nrs
```

Afecta a lo que se consume vía `pkgs.unstable.*`: `claude-code`, `brave`,
`firefox`, `proton-vpn` y **`sail`** (que en korriban corre como servicio).
Es el input que más se mueve.

### 3. Todos los inputs

```bash
nix flake update
nrs
```

### Subir de release (cada ~6 meses)

Editar la rama del input en `flake.nix`:

```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.11";   # antes: nixos-26.05
```

y después `nix flake update nixpkgs`.

> **`system.stateVersion` NO se toca nunca.** No es "la versión que uso", sino
> con qué versión se instaló la máquina: le dice a NixOS qué migraciones de
> datos aplicar. Cambiarlo puede romper servicios con estado en silencio.

Conviene comprobar antes si el release actual sigue vivo (cada uno se mantiene
hasta ~1 mes después del siguiente):

```bash
nix flake metadata github:NixOS/nixpkgs/nixos-26.05 --json \
  | jq -r '.lastModified | strftime("%Y-%m-%d")'
```

Si la última commit es de hace semanas, la rama está congelada = EOL. Así se
detectó que 25.11 llevaba muerta desde el 30 de junio de 2026.

### Flujo seguro

Recomendado siempre, **obligatorio** al subir de release:

```bash
nixos-rebuild build --flake .#hades                    # construye, no activa
nix store diff-closures /run/current-system ./result   # qué cambia exactamente
nrs                                                     # si convence
```

Para korriban, validando desde hades sin tocar el server:

```bash
nixos-rebuild build --flake .#korriban
nix copy --to ssh://root@korriban $(readlink -f result)   # por LAN, más rápido
```

### Revertir

```bash
git checkout flake.lock          # antes de aplicar: deshace la actualización
sudo nixos-rebuild --rollback    # ya aplicado: generación anterior
git revert <commit>              # deja la reversión en el historial
```

Y siempre queda elegir una generación anterior en el menú de arranque.

**Ritmo recomendado:** nivel 1 cada pocas semanas; nivel 3 antes de ponerse con
algo gordo, no en medio. El salto de release, **nunca el mismo día que otros
cambios**: si algo se rompe, quieres que la única variable sea el release.

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
| `Super + E` | Gestor de ficheros (thunar) — **solo Hyprland** |
| `Super + C` | Cerrar ventana |
| `Super + F` | Fullscreen |
| `Super + L` | Bloquear pantalla |
| `Super + M` (Hyprland) · `Super+Shift+E` (Niri) | Salir de la sesión |
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
