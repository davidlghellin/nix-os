{ config, pkgs, lib, ... }:

##############################################################################
## MEDIA (Jellyfin + Transmission + MiniDLNA).
## Reutilizable: lo importa el server (Korriban) y también el portátil (hades),
## para tener los servicios a mano estés donde estés.
##
## Nota: MiniDLNA indexa "/media/disk_dlg" (disco externo del server). En una
## máquina sin ese disco simplemente lo ignora con un warning; no falla.
##############################################################################
{
  ##########################################################################
  ## Minidlna
  ##########################################################################
  services.minidlna = {
    enable = true;
    settings = {
      media_dir = [
        "V,/home/wizord/multimedia/Torrents"
        "/media/disk_dlg"
      ];
      friendly_name = config.networking.hostName;
      inotify = "yes";
      notify_interval = 900;
      port = 8200;
    };
  };

  users.users.minidlna.extraGroups = [ "users" "media" ];

  ##########################################################################
  ## Jellyfin
  ##########################################################################
  services.jellyfin = {
    enable = true;
    user = "wizord";
    openFirewall = true;  # Abre puertos 8096 (HTTP) y 8920 (HTTPS)
  };

  ##########################################################################
  ## Transmission
  ##########################################################################
  systemd.tmpfiles.rules = [
    "d /home/wizord/multimedia              0755 wizord users -"
    "d /home/wizord/multimedia/Torrents     0755 wizord users -"
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
    user = "wizord";
    openFirewall = true;

    settings = {
      download-dir = "/home/wizord/multimedia/Torrents";
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
    allowedTCPPorts = [ 8200 9091 51413 ];
    allowedUDPPorts = [ 51413 ];
  };
}
