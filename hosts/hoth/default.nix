{ pkgs, lib, ... }:

##############################################################################
## hoth — portátil blanco de mis padres.
## common + desktop-xfce (XFCE, ligero: es un portátil viejo).
##
## Usuarios:
##   wizord   → el de la instalación: admin (sudo), mantenimiento por SSH.
##              Oculto en la pantalla de login para que no lo toquen.
##   padre    → sin sudo. Contraseña tras el primer switch: sudo passwd padre
##   madre    → ídem.
##   invitado → sin contraseña y con el home en RAM: cada reinicio sale limpio.
##############################################################################
let
  invitadoUid = 1100;               # fijo: el tmpfs de su home lo necesita

  # Carpeta única de películas: aquí descarga Transmission, aquí guardan
  # padre y madre lo que bajen con el navegador, y esto sirve MiniDLNA a la tele.
  peliculas = "/srv/peliculas";
in
{
  imports = [
    ./hardware.nix                  # sudo cp /etc/nixos/hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop-xfce.nix
    ../../modules/media.nix       # Transmission + MiniDLNA (Jellyfin se apaga abajo)

    # "media": pueden escribir en /srv/peliculas (el invitado no).
    (import ../../lib/mkUser.nix { nombre = "padre"; descripcion = "Papá"; extraGroups = [ "media" ]; })
    (import ../../lib/mkUser.nix { nombre = "madre"; descripcion = "Mamá"; extraGroups = [ "media" ]; })
    (import ../../lib/mkUser.nix {
      nombre = "invitado";
      descripcion = "Invitado";
      red = false;                  # usa la wifi de casa, no la cambia
    })
  ];

  networking.hostName = "hoth";

  ##########################################################################
  ## Wifi: Realtek RTL8723DE
  ##########################################################################
  # La lleva el driver del kernel (rtw88_8723de); solo necesita el firmware.
  # (El rtl8821ce que traía el configuration.nix de la instalación era para
  # otra tarjeta: no hacía nada.)
  hardware.enableRedistributableFirmware = true;

  ##########################################################################
  ## Invitado
  ##########################################################################
  users.users.invitado = {
    uid = invitadoUid;
    # "" = entra sin contraseña en local; por SSH, su o sudo NO (lo dice la
    # doc de users.users.<name>.hashedPassword).
    hashedPassword = "";
  };

  # Home en RAM: lo que deje (descargas, sesiones del navegador…) se borra al
  # reiniciar. gid 100 = grupo "users", el de isNormalUser.
  fileSystems."/home/invitado" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2G" "mode=0700" "uid=${toString invitadoUid}" "gid=100" ];
  };

  # En la pantalla de login solo salen Papá, Mamá e Invitado. LightDM saca la
  # lista de AccountsService, que no enseña las cuentas marcadas SystemAccount.
  systemd.tmpfiles.rules = [
    "f+ /var/lib/AccountsService/users/wizord 0600 root root - [User]\\nSystemAccount=true\\n"
    # Carpeta de películas (ver "Películas" más abajo).
    "d ${peliculas} 2775 wizord media -"
  ];

  # media.nix trae también Jellyfin; aquí sobra: la tele tira de MiniDLNA.
  services.jellyfin.enable = lib.mkForce false;

  ##########################################################################
  ## Películas: una sola carpeta para todos
  ##########################################################################
  # media.nix descarga en /home/wizord/multimedia/Torrents, donde padre y
  # madre no llegan. Aquí todo va a /srv/peliculas, del grupo "media" (wizord,
  # padre, madre y minidlna están en él). El 2 de 2775 (setgid) hace que lo
  # que se cree dentro herede el grupo, venga de Transmission o del navegador.
  # La crea tmpfiles, no transmission-setup: en 26.05 esa unidad solo tiene
  # before/partOf y nadie la arranca, así que la carpeta no llegaba a existir
  # y transmission moría con "Failed to set up mount namespacing". media.nix
  # ya ordena transmission detrás de systemd-tmpfiles-setup. (El aviso del
  # módulo contra tmpfiles es por /home/<otro>; /srv es de root, no aplica.)
  # La regla está junto a la de AccountsService, en systemd.tmpfiles.rules.
  services.transmission = {
    group = "media";
    settings.download-dir = lib.mkForce peliculas;
  };
  services.minidlna.settings.media_dir = lib.mkForce [ "V,${peliculas}" ];

  # Acceso directo "Películas" en el home de cada uno, para el explorador y
  # para el "Guardar como" del navegador. Si ya existe, no lo toca.
  system.userActivationScripts.peliculas =
    "[ -e ~/Películas ] || ln -s ${peliculas} ~/Películas";

  # media.nix solo abre 8200/tcp. Sin 1900/udp (SSDP) la tele no recibe
  # respuesta cuando busca servidores y solo ve hoth cuando minidlna se
  # anuncia (cada 15 min). La rpi3 lo tenía abierto; openFirewall abre ambos.
  services.minidlna.openFirewall = true;

  # media.nix abre la web de Transmission a toda la red. Aquí, sin contraseña
  # (decisión consciente: comodidad para el móvil) pero solo desde la LAN:
  # el móvil con una app tipo Transdroid, http://192.168.1.202:9091 (IP fija
  # reservada en la FRITZ!Box). El host-whitelist sigue activo contra DNS
  # rebinding; entrando por IP siempre vale.
  services.transmission.settings = {
    rpc-bind-address = lib.mkForce "0.0.0.0";
    rpc-whitelist-enabled = lib.mkForce true;
    rpc-whitelist = "127.0.0.1,::1,192.168.1.*";
    rpc-host-whitelist-enabled = lib.mkForce true;
  };

  ##########################################################################
  ## Rendimiento: disco mecánico viejo
  ##########################################################################
  # No escribir en disco cada vez que se LEE un fichero.
  fileSystems."/".options = [ "noatime" ];

  # BFQ reparte el disco por procesos: el escritorio responde aunque haya una
  # descarga o una actualización machacando el HDD.
  boot.kernelModules = [ "bfq" ];
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # autoUpgrade y el GC compilan y escriben mucho: que solo usen disco y CPU
  # cuando nadie más los quiere.
  nix.daemonIOSchedClass = "idle";
  nix.daemonCPUSchedPolicy = "idle";

  # Si el navegador se come la RAM, mata lo que más gasta en vez de dejar el
  # portátil congelado minutos (con HDD, tirar de swap es eterno).
  services.earlyoom.enable = true;

  ##########################################################################
  ## Portátil
  ##########################################################################
  services.thermald.enable = true;  # temperatura de Intel (Kaby Lake)
  services.fwupd.enable = true;     # BIOS/firmware si el fabricante lo publica

  # Versión del ISO con el que se instaló. No se toca nunca más.
  system.stateVersion = "26.05";

  ##########################################################################
  ## Mantenimiento en remoto
  ##########################################################################
  environment.systemPackages = [
    pkgs.rustdesk-flutter           # ver su pantalla cuando llamen ("no me sale el botón")
    # Ventana para el Transmission del sistema: añadir torrents, ver cómo van.
    # Abre los enlaces magnet del navegador. Conecta a localhost:9091.
    pkgs.transmission-remote-gtk
  ];

  # Se actualiza solo desde GitHub: push a master y esa noche lo aplica.
  # Si algo sale mal, generación anterior en el menú de arranque.
  system.autoUpgrade = {
    enable = true;
    flake = "github:davidlghellin/nix-os#hoth";
    dates = "03:00";
    randomizedDelaySec = "45min";
    allowReboot = false;            # nunca reiniciarles en mitad de algo
  };

  # Si a las 3:00 estaba apagado, lo hace al encenderlo.
  systemd.timers.nixos-upgrade.timerConfig.Persistent = true;
}
