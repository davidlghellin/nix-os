{ inputs, modulesPath, pkgs, ... }:

##############################################################################
## emulador — Raspberry Pi 3 dedicada a emulación retro (RetroArch).
##
## Host LIGERO a propósito: no importa common.nix (que trae CLI de escritorio,
## claude-code, etc.). Solo lo justo para arrancar la Pi + el módulo emulator.
##
## ─────────────────────────────────────────────────────────────────────────
## CHULETA DE COMANDOS
## ─────────────────────────────────────────────────────────────────────────
##
## 1) PRIMERA VEZ — construir imagen SD y flashear (la Pi aún no tiene NixOS):
##
##    # Construir la imagen (se compila en hades, casi todo baja de la caché):
##    nix build .#nixosConfigurations.emulador.config.system.build.sdImage
##    # La imagen queda en:  ./result/sd-image/*.img
##
##    # Flashear la SD (⚠️ /dev/sdX = tu tarjeta; BORRA todo. Desmóntala antes):
##    sudo umount /dev/sdX*        # desmonta particiones si estaban montadas
##    sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M conv=fsync status=progress
##
##    # Meter SD en la Pi + cable de red + HDMI → arranca RetroArch a pantalla
##    # completa. SSH: `ssh wizord@<ip>` (pass inicial "nixos", cámbiala con passwd).
##
## 2) ACTUALIZAR — ya arrancando, cambios de config por SSH (lo normal):
##
##    nixos-rebuild switch --flake .#emulador \
##      --target-host wizord@<ip> --ask-sudo-password
##
## 3) METER ROMS — por SSH a las carpetas por consola (NO van en el repo):
##
##    scp "Sonic.md"  wizord@<ip>:/home/wizord/roms/megadrive/
##    rsync -av ~/roms/  wizord@<ip>:/home/wizord/roms/     # carpetas enteras
##    # Con las playlists autogeneradas, los juegos aparecen SOLOS en el menú.
##
## ─────────────────────────────────────────────────────────────────────────
## NOTA DE ESTADO (2026-09-01)
## ─────────────────────────────────────────────────────────────────────────
## La Pi `emulador` (192.168.1.245) YA funciona: RetroArch fullscreen, sonido
## HDMI, mando (Start+Select = menú), listas por consola, sin cursor. Se montó
## a base de ajustes EN CALIENTE por SSH — casi todos persisten a reinicios,
## pero el cursor oculto (estaba en /run) y el auto-refresco de listas NO.
##
## Este módulo YA reproduce ese estado exacto + lo hace permanente. Para
## aplicarlo del todo hay que REFLASHEAR una vez (el 1er deploy no puede ir por
## SSH: rutas locales sin firmar y wizord aún no trusted en la Pi corriendo):
##
##    nix build .#nixosConfigurations.emulador.config.system.build.sdImage
##    sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M conv=fsync status=progress
##    rsync -av ~/roms/  wizord@192.168.1.245:/home/wizord/roms/   # reponer ROMs
##
## Tras ese reflasheo, los cambios futuros SÍ van por SSH (nixos-rebuild
## switch --flake .#emulador --target-host wizord@192.168.1.245 --ask-sudo-password).
##
## Apaño sin reflashear, si tras un reinicio reaparece el cursor (el tema
## transparente ya está copiado en ~/blankicons de la Pi):
##    sudo mkdir -p /run/systemd/system/cage-tty1.service.d
##    printf '[Service]\nEnvironment=XCURSOR_THEME=blank\nEnvironment=XCURSOR_PATH=/home/wizord/blankicons\n' \
##      | sudo tee /run/systemd/system/cage-tty1.service.d/cursor.conf
##    sudo systemctl daemon-reload && sudo systemctl restart cage-tty1
##############################################################################
{
  imports = [
    # Genera una imagen SD arrancable para aarch64. Monta la cadena de
    # arranque completa para RPi 3: config.txt con `kernel=u-boot-rpi3.bin`,
    # copia u-boot, y u-boot lee extlinux → carga el kernel MAINLINE.
    #
    # OJO: NO importar `nixos-hardware.raspberry-pi-3` aquí. Ese módulo
    # sobrescribe la config de firmware con la suya (kernel del vendor, sin
    # u-boot), y rompe el arranque con el kernel mainline (config.txt se queda
    # sin kernel ni u-boot que cargar → pantalla negra, sin red). Para el
    # emulador (por cable, sin wifi) no aporta nada y estorba.
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    # El emulador en sí.
    ../../modules/emulator.nix
  ];

  # Kernel MAINLINE (es el default de NixOS, `pkgs.linuxPackages`). Al no usar
  # nixos-hardware, nadie fuerza el `linux-rpi` del vendor. El mainline aarch64
  # está cacheado en Hydra → la imagen se DESCARGA en vez de compilarse emulada,
  # y arranca vía u-boot (que sí monta sd-image-aarch64).
  boot.kernelPackages = pkgs.linuxPackages;

  networking = {
    hostName = "emulador";
    # NetworkManager gestiona ethernet (DHCP) y deja el WiFi listo para el
    # futuro (`nmcli device wifi connect ...`) sin reconstruir.
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];     # solo SSH
    };
  };

  ##########################################################################
  ## WiFi + Bluetooth (para mandos inalámbricos: 8BitDo, Xbox, PS4/PS5...)
  ##########################################################################
  # Firmware del chip Broadcom de la RPi3 (WiFi brcmfmac + parche BT).
  hardware.enableRedistributableFirmware = true;

  # Stack Bluetooth (BlueZ). Empareja mandos con `bluetoothctl`.
  # NOTA: el BT ONBOARD de la RPi3 (por UART) es históricamente delicado con
  # kernel mainline. Si da guerra, un dongle USB Bluetooth (~5€) es enchufar
  # y listo — con esto ya activado, funciona sin tocar nada más.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";
  console.keyMap = "es";

  users.users.wizord = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nixos";      # cámbiala con `passwd` tras el primer login
    openssh.authorizedKeys.keys = [
      # Pon aquí tu clave pública SSH para entrar sin contraseña:
      # "ssh-ed25519 AAAA..."
    ];
  };

  services.openssh.enable = true;
  services.getty.helpLine = ''
    IP: \4
  '';

  # Imagen sin comprimir (más rápida de flashear; el .img se usa directo).
  sdImage.compressImage = false;

  # RPi 3 = 1 GB RAM → zram como swap comprimida.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Aligerar: sin manuales ni docs en una consola de juegos.
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Permite desplegar por SSH desde hades (nix copy de rutas construidas
  # localmente) sin pelear con firmas.
  nix.settings.trusted-users = [ "root" "wizord" ];

  # Firmware WiFi/BT de la Pi es redistribuible pero "unfree".
  nixpkgs.config.allowUnfree = true;

  boot.loader.generic-extlinux-compatible.configurationLimit = 4;

  system.stateVersion = "26.05";
}
