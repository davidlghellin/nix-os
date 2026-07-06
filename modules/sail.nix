{ pkgs, ... }:

##############################################################################
## SAIL — motor compute compatible con Spark (LakeSail) siempre corriendo.
##
## `sail` está en nixpkgs (pkgs/by-name/sa/sail, mainProgram = "sail"), así que
## basta con lanzar el binario como servicio systemd. Usamos la versión de
## unstable (mismo patrón que unstable.claude-code en common.nix); en estable
## 25.11 el paquete aún no existe.
##
## Levantamos DOS interfaces, cada una en su puerto (son procesos independientes
## que conviven sin problema):
##   - Spark Connect    → gRPC   sc://korriban:50051
##   - Arrow Flight SQL → gRPC        korriban:32010
##
## Los puertos se abren en el firewall aquí abajo.
##############################################################################
let
  sail = pkgs.unstable.sail;

  sparkPort = 50051;
  flightPort = 32010;

  # Fábrica de units: mismo esqueleto para spark y flight, solo cambia el
  # subcomando y el puerto. Ambas corren como el usuario dedicado `sail`.
  mkSailService = { description, args }: {
    inherit description;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${sail}/bin/sail ${args}";
      User = "sail";
      Group = "sail";
      Restart = "on-failure";
      RestartSec = 5;
      StateDirectory = "sail";        # /var/lib/sail (dir de trabajo compartido)
      WorkingDirectory = "/var/lib/sail";
    };
  };
in
{
  ##########################################################################
  ## Usuario de servicio dedicado (compartido por ambas units)
  ##########################################################################
  users.users.sail = {
    isSystemUser = true;
    group = "sail";
  };
  users.groups.sail = {};

  ##########################################################################
  ## Servicios
  ##########################################################################
  systemd.services.sail-spark = mkSailService {
    description = "Sail — Spark Connect server (LakeSail)";
    args = "spark server --ip 0.0.0.0 --port ${toString sparkPort}";
  };

  systemd.services.sail-flight = mkSailService {
    description = "Sail — Arrow Flight SQL server (LakeSail)";
    args = "flight server --ip 0.0.0.0 --port ${toString flightPort}";
  };

  ##########################################################################
  ## CLI de sail disponible en el sistema (para pruebas / cliente)
  ##########################################################################
  environment.systemPackages = [ sail ];

  ##########################################################################
  ## Firewall — el módulo abre sus dos puertos (autocontenido: no depende de
  ## server.nix). Spark Connect + Flight SQL.
  ##########################################################################
  networking.firewall.allowedTCPPorts = [ sparkPort flightPort ];
}
