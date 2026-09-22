##############################################################################
## Podman disponible (daemonless → NO hay demonio de fondo consumiendo; solo el
## binario + su config). Permite lanzar contenedores a demanda (`podman run …`)
## y declararlos con virtualisation.oci-containers cuando haga falta.
##
## Se importa SOLO en los hosts que lo quieren (hades, korriban), NO en
## common.nix, porque hay máquinas donde no lo quiero.
##############################################################################
{ pkgs, ... }:

{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;      # deja el comando `docker` como alias de podman
    dockerSocket.enable = true;  # /run/docker.sock rootful (socket-activated)

    # Limpieza automática (1×/semana): borra imágenes/contenedores/volúmenes
    # colgados para que no se acumule basura en disco. Un timer, sin mantenimiento.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Herramientas que hablan "docker" apuntan al socket ROOTLESS de podman del
  # usuario (uid 1000 = wizord, primer usuario). Así `docker`/lazydocker ven TUS
  # contenedores rootless, sin depender del socket rootful ni de sudo.
  environment.sessionVariables.DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";

  # TUI para gestionar contenedores/imágenes (mejor que ctop, y nativo → no
  # necesita montar sockets como el contenedor de ctop).
  environment.systemPackages = [ pkgs.lazydocker ];

  ##########################################################################
  ## EJEMPLO (comentado): "docker-compose a la NixOS" con oci-containers.
  ## ------------------------------------------------------------------------
  ## Backend de datos de dev: MinIO (S3) + Postgres. Cada contenedor se vuelve
  ## una systemd unit (podman-minio.service / podman-pg.service) → restart,
  ## orden, logs en journald, todo declarativo.
  ##
  ## PARA QUÉ: un S3 LOCAL para probar sail (`s3://…` con endpoint
  ## http://localhost:9000) + una BBDD SQL de pruebas.
  ##
  ## DÓNDE: descomenta para dev local en hades, o mejor en korriban (always-on)
  ## si lo quieres permanente. Puertos atados a 127.0.0.1 (solo local).
  ## Nota: son servicios always-on (consumen aunque no los uses) → actívalo solo
  ## cuando lo vayas a usar de verdad.
  #
  #   virtualisation.oci-containers = {
  #     backend = "podman";
  #     containers.minio = {
  #       image = "quay.io/minio/minio";
  #       cmd = [ "server" "/data" "--console-address" ":9001" ];
  #       environment = { MINIO_ROOT_USER = "dev"; MINIO_ROOT_PASSWORD = "devsecret"; };
  #       ports = [ "127.0.0.1:9000:9000" "127.0.0.1:9001:9001" ];  # API S3 + consola web
  #       volumes = [ "minio:/data" ];
  #       extraOptions = [ "--network=devdata" ];
  #     };
  #     containers.pg = {
  #       image = "postgres:16";
  #       environment = { POSTGRES_USER = "dev"; POSTGRES_PASSWORD = "devsecret"; POSTGRES_DB = "dev"; };
  #       ports = [ "127.0.0.1:5432:5432" ];
  #       volumes = [ "pgdata:/var/lib/postgresql/data" ];
  #       extraOptions = [ "--network=devdata" ];
  #     };
  #   };
  #   # compose crea la red sola; aquí un oneshot que la crea si no existe:
  #   systemd.services.init-devdata-net = {
  #     wantedBy = [ "multi-user.target" ];
  #     before = [ "podman-minio.service" "podman-pg.service" ];
  #     serviceConfig.Type = "oneshot";
  #     script = "${pkgs.podman}/bin/podman network exists devdata || ${pkgs.podman}/bin/podman network create devdata";
  #   };
  ##########################################################################
}
