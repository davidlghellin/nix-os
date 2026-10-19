{ config, pkgs, ... }:

##############################################################################
## Korriban — el server (headless homelab).
## Solo cosas de server: red + SSH (common) + servicios (server) + GPU AMD
## para el transcoding de Jellyfin. Sin escritorio.
##############################################################################
{
  imports = [
    ./hardware.nix
    ../../modules/common.nix
    ../../modules/server.nix
    ../../modules/podman.nix
    ../../modules/media.nix
    ../../modules/gpu-amd.nix
    ../../modules/sail.nix
  ];

  networking.hostName = "Korriban";

  # Apagado nocturno a las 00:30 con encendido automático a las 07:00 vía
  # alarma RTC (probado con `rtcwake -m off -s 120`: la placa arranca sola).
  #
  # El encendido lo hace el reloj de la placa (RTC), no systemd: con el equipo
  # apagado no corre nada. La alarma RTC es de un solo uso (se borra al
  # dispararse) y solo cabe una, así que hay que reprogramarla cada noche
  # antes de apagar. Si se apaga a mano antes de las 00:30, no se programa
  # y no se encenderá solo.
  #
  # El service es el "qué" y el timer el "cuándo"; se enlazan por el nombre.
  systemd.services.nightly-poweroff = {
    description = "Apagar y programar encendido a las 07:00";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.util-linux pkgs.coreutils config.systemd.package ];
    script = ''
      # Programa el despertador para las 07:00 de hoy (a las 00:30 ya es el
      # día nuevo). `-m no`: solo pone la alarma, no apaga. `-u`: RTC en UTC.
      rtcwake -m no -u -t "$(date +%s -d '07:00')"
      # Apagado limpio: para los servicios en orden y corta la corriente.
      systemctl poweroff
    '';
  };

  # Lanzador: cada día a las 00:30 ejecuta el service del mismo nombre.
  systemd.timers.nightly-poweroff = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*-*-* 00:30:00";
  };
}
