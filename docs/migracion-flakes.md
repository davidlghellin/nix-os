# Migración del repo NixOS a flakes — plan revisado

> Notas de trabajo (jul 2026). Objetivo: pasar el repo de **channels** a **flakes**
> reutilizando `hosts/` + `modules/`, sin rediseñar de cero.
> Revisado contra el código real del repo (jul 2026): se corrigen inputs
> sobrantes y se añaden los blockers de pureza que el plan original no veía.

## Decisiones tomadas

- **home-manager: diferido.** Se deja un slot `modules/home/` para adoptarlo luego
  sin reescribir. Hasta entonces, `dotfiles/` a mano como ahora.
- **Raspberry: DIFERIDA (jul 2026).** Sigue en su flake aparte (`rpi3/`) hasta poder
  probar con la rasp delante. Cuando se migre: al flake raíz como un host más
  (`nixosConfigurations.rpi3`, `system = "aarch64-linux"`), NO como flake aparte —
  el aislamiento se logra por lista-de-módulos, no por separar el flake.
  El input `nixos-hardware` se añadirá entonces (hoy solo lo consume la rasp).
- single-user, unstable pineado como input, cross-compile aarch64 desde x86.

### Correcciones sobre el plan original (verificadas contra el repo)

- **Un solo `nixpkgs`, no dos.** Hades ya está en 25.11 (`nixos-version` = 25.11.12484)
  y el flake de rpi3 también usa `nixos-25.11`. El input `nixpkgs-2511` "para la rasp"
  era redundante → eliminado. Inputs finales: `nixpkgs` (25.11), `nixpkgs-unstable`,
  `nixos-hardware` (solo lo consume rpi3).
- **Fuera `rust-overlay` y `dev/rust.nix`.** El repo gestiona Rust con `rustup`
  (`modules/desktop.nix`: rustup + rust-analyzer + maturin), incompatible por diseño
  con rust-overlay (harían lo mismo por dos vías). Los `flakes/sail/*` son devshells
  Python, no Rust. Si algún día hace falta, se añade en 3 líneas.
- **`flakes/sail/*` se quedan como están.** Un subflake no puede hacer `follows` del
  input del padre. Que cada devshell pinee su propio unstable es lo correcto: se
  bumpean sin tocar el sistema. (Alternativa descartada: exponer `devShells` desde el
  flake raíz — un solo pin, pero se pierde direnv-por-carpeta y se acoplan los dev
  envs al release del sistema.)
- **korriban**: `networking.hostName = "Korriban"` (mayúscula) se queda; el atributo
  del flake es `korriban` en minúscula (`.#korriban`). Son cosas distintas.
- **`hosts/default.nix`**: con flakes no hay fallback por hostname. Se convierte en
  `nixosConfigurations.generic` (plantilla para clonar máquinas nuevas) o se borra.

---

## Blockers de pureza (van ANTES del flake — se arreglan y validan aún con channels)

1. **`modules/desktop.nix:298`** → `cp ${/home/wizord/Images/plant.jpg} …`
   Ruta absoluta fuera del árbol del flake = error duro en eval puro
   (*"access to absolute path … is forbidden in pure evaluation mode"*).
   Fix: meter la imagen en el repo → `assets/plant.jpg` → `${../assets/plant.jpg}`.
   Es el fallo más probable del primer `nixos-rebuild build --flake`.

2. **`modules/common.nix:310`** → el overlay de unstable no pasa `system`.
   Sin él, nixpkgs cae en `builtins.currentSystem`, que NO existe en eval puro.
   Al pasarlo a input:

   ```nix
   nixpkgs.overlays = [
     (final: prev: {
       unstable = import inputs.nixpkgs-unstable {
         inherit (final.stdenv.hostPlatform) system;   # imprescindible
         config.allowUnfree = true;
       };
     })
   ];
   ```

   Consumidores que siguen funcionando igual: `common.nix:285` (claude-code),
   `desktop.nix:324-327`, `sail.nix:19`, `hades.nix:20`.

3. **`nix-shell -p` se rompe al quitar channels** (`common.nix:174`, `.zshrc:76-78`
   dependen de `<nixpkgs>` vía `NIX_PATH`). Fix en common.nix:

   ```nix
   nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
   nix.registry.nixpkgs.flake = inputs.nixpkgs;  # `nix shell nixpkgs#x` usa el pin
   ```

4. **`git add` obligatorio.** El flake solo ve ficheros trackeados. `flake.nix`,
   `hosts/*/hardware.nix` y `assets/plant.jpg` nuevos sin añadir → "file not found"
   desconcertante.

Falsa alarma descartada: `environment.etc."direnv/direnv.toml"` usa `.text`
(string inline), sin problema de pureza. No hay más `${/ruta-absoluta}` en el repo.

---

## Árbol objetivo (reutiliza lo actual; **negrita** = nuevo)

```
.
├── flake.nix / flake.lock          ← NUEVO: raíz única
├── lib/mkHost.nix                  ← NUEVO: helper que arma cada host (mata duplicación)
├── assets/plant.jpg                ← NUEVO: wallpaper SDDM al repo (blocker 1)
├── hosts/
│   ├── hades/{default.nix,hardware.nix}      ← hardware.nix ENTRA al repo
│   ├── korriban/{default.nix,hardware.nix}
│   └── rpi3/{default.nix,hardware…,adguard-userrules.txt}  ← la rasp, como un host más
├── modules/
│   ├── system/                     ← los modules/*.nix de hoy, tal cual (fase cosmética)
│   └── home/                       ← VACÍO: slot para home-manager (luego)
├── flakes/                         ← devshells (sail…) siguen igual, pin propio
└── dotfiles/                       ← igual, hasta adoptar home-manager
```

Notas de `mkHost`: a `nixosSystem` NO se le pasa `pkgs`; `nixpkgs.config` /
`nixpkgs.overlays` los sigue poniendo `common.nix`, así los módulos no se tocan.

---

## Fases (bajo riesgo, un commit por paso, `build` antes de `switch`)

1. **Rama + red de seguridad.** `git switch -c flakes-migration`. Nada se activa
   hasta validar. Antes de nada: comprobar en korriban `nixos-version` — si está en
   25.05, migrar con el input en `nixos-25.05` y bumpear a 25.11 en commit aparte
   (un cambio por commit, nunca migración + upgrade juntos).
2. **Pureza primero** (aún con channels; `nixos-rebuild build` valida cada paso):
   - `~/Images/plant.jpg` → `assets/plant.jpg`, ajustar `desktop.nix:298`.
   - `/etc/nixos/hardware-configuration.nix` de cada máquina →
     `hosts/<host>/hardware.nix`. **Sí hace falta**: en eval puro el flake no puede
     leer rutas absolutas fuera del repo; sin esto, cada rebuild necesitaría
     `--impure` (adiós reproducibilidad). Solo contiene UUIDs de discos y módulos
     de kernel, nada sensible. El de hades entra ya; el de korriban queda como
     stub con `throw` (mensaje claro) hasta copiarlo desde la máquina — la eval
     es lazy, así que hades construye igual.
3. **`flake.nix` + `lib/mkHost.nix`.** Inputs: `nixpkgs` (25.11) y
   `nixpkgs-unstable`. Outputs: `nixosConfigurations.{hades,korriban}`.
4. **Pinear unstable.** El `fetchTarball` de `common.nix:310` → overlay alimentado
   por el input, con `system` explícito (blocker 2). `pkgs.unstable.*` sigue igual,
   pero pineado en `flake.lock`.
5. **`nix.nixPath` + `nix.registry`** (blocker 3), para que `nix-shell -p` y
   `nix shell nixpkgs#…` sigan funcionando sin channels.
6. **Validar sin activar:** `nixos-rebuild build --flake .#hades` (sin sudo, no toca
   el sistema). Si compila → `sudo nixos-rebuild switch --flake .#hades`.
   Repetir en korriban.
7. **Matar el dispatcher y los channels.**
   - Borrar `configuration.nix` y el symlink `/etc/nixos/configuration.nix`.
   - `nrs` (`common.nix:155`) →
     `sudo nixos-rebuild switch --flake /home/wizord/nix-os#$(hostname | tr A-Z a-z) |& nom`
   - `sudo nix-channel --remove nixos`.
8. **rpi3 al flake raíz — DIFERIDA hasta tener la rasp delante para probar.**
   `rpi3/` → `hosts/rpi3/`, SIN `common.nix` (arrastraría binfmt + overlay
   unstable cross-compilado a aarch64). Añadir input `nixos-hardware` entonces.
   Ojo con dos cosas:
   - **Mover `adguard-userrules.txt` junto al host**: `rpi3/configuration.nix:117`
     hace `builtins.readFile ./adguard-userrules.txt` (relativo al .nix).
   - **Re-pin consciente**: el `rpi3/flake.lock` viejo congela nixpkgs-25.11 en
     `54170c5` (meses atrás); el lock raíz traerá el HEAD actual → bump de todos
     los paquetes de la rasp. O se acepta y se valida el `toplevel`/`sdImage`
     antes de desplegar, o se pinea el input a ese rev y se bumpea en commit aparte.
   - Validar: `nix build .#nixosConfigurations.rpi3.config.system.build.sdImage`.
9. **Cosmético (opcional, al final):** `modules/` → `modules/system/`, crear
   `modules/home/` vacío. Extraer `adguard.nix`/`homepage.nix` del monolito de la
   rasp si se quiere reuso real de módulos — mejora aparte, no parte de la migración.

---

## Mantenibilidad (lo que se gana)

- **Actualizar** = `nix flake update` → diff en `flake.lock` revisable y reversible.
  Se acabó el "cada máquina con un unstable distinto".
- **Añadir máquina** = 1 carpeta `hosts/<nueva>/` + 1 línea en `flake.nix`.
- **Rollback** = `git revert` del lock o `nixos-rebuild --rollback`.

## Antipatterns que esta estructura elimina

- **`if hostname == …`** → cada host declara su lista de módulos explícita.
- **Duplicación de nixpkgs** → inputs pineados y compartidos.
- **Módulos acoplados / dependencias implícitas** → cada módulo autocontenido;
  nada asume que "otro módulo se importó antes".
- **Config no reproducible** → `flake.lock` fija todo; hades y korriban construyen
  igual; el overlay de unstable deja de moverse solo (`fetchTarball` sin pin).
