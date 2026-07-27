{ config, pkgs, lib, ... }:

##############################################################################
## MEDIA (Jellyfin + Transmission + MiniDLNA).
## Reutilizable: lo importa el server (Korriban) y también el portátil (hades),
## para tener los servicios a mano estés donde estés.
##
## Nota: MiniDLNA indexa "/media/disk_dlg" (disco externo del server). En una
## máquina sin ese disco simplemente lo ignora con un warning; no falla.
##############################################################################
let
  # Dueño de los servicios y de la biblioteca. Es el admin de common.nix: los
  # torrents y la biblioteca de Jellyfin viven en su home, así que si algún día
  # se monta esto en un equipo de otra persona, se cambia aquí y ya.
  usuario = "wizord";
  biblioteca = "/home/${usuario}/multimedia";
in
{
  ##########################################################################
  ## Minidlna
  ##########################################################################
  services.minidlna = {
    enable = true;
    settings = {
      media_dir = [
        "V,${biblioteca}/Torrents"
        "/media/disk_dlg"
      ];
      friendly_name = config.networking.hostName;
      inotify = "yes";
      notify_interval = 900;
      port = 8200;
    };
  };

  users.users.minidlna.extraGroups = [
    "users"
    "media"
  ];

  ##########################################################################
  ## Jellyfin
  ##########################################################################
  services.jellyfin = {
    enable = true;
    user = usuario;
    openFirewall = true;  # Abre puertos 8096 (HTTP) y 8920 (HTTPS)
  };

  ##########################################################################
  ## Transmission
  ##########################################################################
  systemd.tmpfiles.rules = [
    "d ${biblioteca}              0755 ${usuario} users -"
    "d ${biblioteca}/Torrents     0755 ${usuario} users -"
  ];

  # El servicio falla en boot con "Failed to set up mount namespacing"
  # si el download-dir no existe todavía. Forzar orden tras tmpfiles.
  systemd.services.transmission = {
    after    = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
  };

  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    user = usuario;
    openFirewall = true;

    settings = {
      download-dir = "${biblioteca}/Torrents";
      incomplete-dir-enabled = false;
      rpc-enabled = true;
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;
      umask = 2;
      download-queue-enabled = true;
      download-queue-size = 3;
    };
  };

  ##########################################################################
  ## Firewall (puertos de media)
  ## MiniDLNA 8200, Transmission RPC 9091 / peer 51413.
  ## (Jellyfin y el peer de Transmission ya se abren con openFirewall.)
  ##########################################################################
  networking.firewall = {
    allowedTCPPorts = [
      8200
      9091
      51413
    ];
    allowedUDPPorts = [ 51413 ];
  };
}
