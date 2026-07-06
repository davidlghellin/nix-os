{ config, pkgs, lib, ... }:

##############################################################################
## SERVER / HOMELAB (Korriban).
## AdGuard + Caddy + Homepage + Jellyfin + Transmission + MiniDLNA.
## Headless: sin escritorio; se accede por SSH y por las webs de cada servicio.
##############################################################################
let
  # Dominio local derivado del hostname (DNS en lowercase).
  # Genera URLs tipo http://jellyfin.korriban, http://torrents.korriban, etc.
  domain = lib.toLower config.networking.hostName;
in
{
  ##########################################################################
  ## DNS rewrites locales (para acceso por nombre en la LAN)
  ##########################################################################
  networking.extraHosts = ''
    127.0.0.1 jellyfin.${domain} torrents.${domain} adguard.${domain} dlna.${domain} homepage.${domain}
  '';

  ##########################################################################
  ## Adblock local (AdGuard Home, UI expuesta a la LAN)
  ## Web UI: http://localhost:3000  o  http://<IP-LAN>:3000
  ## (primer arranque: crear usuario y listas)
  ##########################################################################
  services.adguardhome = {
    enable = true;
    mutableSettings = true;  # permite cambios desde la web UI
    settings = {
      http.address = "0.0.0.0:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  networking.nameservers = [ "127.0.0.1" ];
  networking.networkmanager.insertNameservers = [ "127.0.0.1" ];

  ##########################################################################
  ## Caddy reverse proxy (URLs limpias para servicios locales)
  ## URLs:
  ##   http://jellyfin.${domain}  → :8096
  ##   http://torrents.${domain}  → :9091
  ##   http://adguard.${domain}   → :3000
  ##   http://dlna.${domain}      → :8200
  ##   http://homepage.${domain}  → :8082
  ## Para que resuelvan en la LAN:
  ##   1. Reservar IP fija de este host en el router.
  ##   2. AdGuard escuchando en LAN (bind_hosts = "0.0.0.0", abrir puerto 53).
  ##   3. AdGuard DNS Rewrites: *.${domain} → IP fija del host.
  ##   4. Router: repartir la IP del host como DNS por DHCP.
  ##########################################################################
  services.caddy = {
    enable = true;
    virtualHosts."http://jellyfin.${domain}".extraConfig = "reverse_proxy localhost:8096";
    virtualHosts."http://torrents.${domain}".extraConfig = "reverse_proxy localhost:9091";
    virtualHosts."http://adguard.${domain}".extraConfig  = "reverse_proxy localhost:3000";
    virtualHosts."http://dlna.${domain}".extraConfig     = "reverse_proxy localhost:8200";
    virtualHosts."http://homepage.${domain}".extraConfig = "reverse_proxy localhost:8082";
  };

  ##########################################################################
  ## Homepage (dashboard único con todos los servicios)
  ## URL: http://homepage.${domain}
  ##########################################################################
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    # Homepage v0.9+ exige el Host header en la allowlist (la pág. de "Host validation
    # failed" se sirve con HTTP 200). Vía Caddy llega "homepage.${domain}"; por puerto
    # directo desde la LAN llega "${domain}:8082".
    allowedHosts = "homepage.${domain},${domain}:8082,192.168.1.180:8082,localhost:8082,127.0.0.1:8082";

    settings = {
      title = "${config.networking.hostName} homelab";
      theme = "dark";
      color = "slate";
      headerStyle = "boxed";
      layout = {
        Media = { style = "row"; columns = 3; };
        Red   = { style = "row"; columns = 2; };
        Datos = { style = "row"; columns = 2; };
      };
    };

    services = [
      {
        Media = [
          { Jellyfin = {
              href = "http://${domain}:8096";
              description = "Servidor multimedia";
              icon = "jellyfin.png";
          }; }
          { Transmission = {
              href = "http://${domain}:9091";
              description = "Cliente torrent";
              icon = "transmission.png";
          }; }
          { DLNA = {
              href = "http://${domain}:8200";
              description = "MiniDLNA";
              icon = "mdi-cast";
          }; }
        ];
      }
      {
        Red = [
          { "AdGuard Home" = {
              href = "http://${domain}:3000";
              description = "DNS adblock";
              icon = "adguard-home.png";
          }; }
        ];
      }
      {
        Datos = [
          # Sail: motor compute (gRPC, sin web UI). Tiles informativos:
          # el href apunta al repo; los endpoints reales son los gRPC.
          { "Sail · Spark Connect" = {
              href = "https://github.com/lakehq/sail";
              description = "sc://${domain}:50051";
              icon = "si-apachespark";
          }; }
          { "Sail · Flight SQL" = {
              href = "https://github.com/lakehq/sail";
              description = "${domain}:32010";
              icon = "si-apachespark";
          }; }
        ];
      }
    ];

    widgets = [
      { resources = {
          cpu = true;
          memory = true;
          disk = "/";
      }; }
      { search = {
          provider = "duckduckgo";
          target = "_blank";
      }; }
    ];
  };

  ##########################################################################
  ## Disco externo disk_dlg
  ##########################################################################
  fileSystems."/media/disk_dlg" = {
    device = "/dev/disk/by-uuid/d15c7085-bd18-4bc0-a0ef-963275396cd9";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
    ];
  };

  ##########################################################################
  ## Firewall (puertos del server)
  ## gRPC 50051, Caddy 80, AdGuard DNS 53 + UI 3000, Homepage 8082.
  ## (Los puertos de media — 8200/9091/51413 — están en modules/media.nix.)
  ##########################################################################
  networking.firewall = {
    allowedTCPPorts = [
      50051
      80
      53
      3000
      8082
    ];
    allowedUDPPorts = [ 53 ];
  };
}
