# NixOS en Raspberry Pi 3

## Requisitos

- PC con NixOS y `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` en la config
- Tarjeta SD (16GB mínimo)
- Cable ethernet

## Compilar la imagen SD

```bash
cd ~/nix-os/rpi3
nix build .#images.rpi3 --extra-experimental-features "nix-command flakes"
```

La imagen se genera en `./result/sd-image/`.

## Flashear la SD

```bash
# Ver qué dispositivo es la SD (normalmente /dev/sdX o /dev/mmcblkX)
lsblk

# Desmontar la SD si está montada
sudo umount /run/media/wizord/SDHC

# Flashear (CAMBIA /dev/sdX por tu dispositivo)
# IMPORTANTE: no usar wildcards con sudo, poner el nombre completo del .img
sudo dd if=result/sd-image/nixos-image-sd-card-25.11.20260410.54170c5-aarch64-linux.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Primer arranque

1. Mete la SD en la RPi
2. Conecta cable ethernet al router
3. Enciende la RPi
4. Busca la IP en tu router (dispositivo "myoboku") o escanea: `nix-shell -p nmap --run "nmap -sn 192.168.1.0/24"`
5. Conéctate: `ssh wizord@<IP>` (password: `nixos`)
6. Cambia el password: `passwd`

## Configurar Adguard Home

1. Entra en `http://<IP>:80` desde el navegador
2. Sigue el wizard de configuración
3. En tu router, pon la IP de la RPi como servidor DNS

## Actualizar la config (desde tu PC)

### Primera vez

Ya configurado en `configuration.nix` (`trusted-users` y `require-sigs = false`). No hay que hacer nada manual.

### Rebuild remoto

```bash
cd ~/nix-os/rpi3
# Edita configuration.nix
nixos-rebuild switch --flake .#rpi3 --target-host wizord@<IP> --sudo --ask-sudo-password
```

## Actualizar nixpkgs (cada 2-3 meses)

```bash
cd ~/nix-os/rpi3
nix flake update --extra-experimental-features "nix-command flakes"
nixos-rebuild switch --flake .#rpi3 --target-host wizord@<IP> --sudo --ask-sudo-password
```

## Seguridad post-setup

Cuando tengas tu clave SSH en la RPi:

1. Añade tu clave pública en `configuration.nix` → `openssh.authorizedKeys.keys`
2. Cambia `PasswordAuthentication = true` a `false`
3. Rebuild

## Servicios incluidos

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| SSH | 22 | Acceso remoto |
| Adguard Home | 80 (web) + 53 (DNS) | Bloqueo de publicidad/tracking |
| MiniDLNA | 8200 + 1900/udp | Servidor multimedia DLNA |

## Disco externo (MiniDLNA)

El disco se monta en `/mnt/media`. Arranca sin él gracias a `nofail`.
Para que lo detecte, el disco debe tener label `MEDIA` (o cambia el `device` en configuration.nix).

```bash
# Para poner label a un disco ext4:
sudo e2label /dev/sdX1 MEDIA
```

## Regenerar imagen desde cero

Si la SD muere o quieres empezar limpio:

```bash
cd ~/nix-os/rpi3
nix build .#images.rpi3 --extra-experimental-features "nix-command flakes"
# Poner el nombre exacto del .img generado
sudo dd if=result/sd-image/<nombre-imagen>.img of=/dev/sdX bs=4M status=progress conv=fsync
```
