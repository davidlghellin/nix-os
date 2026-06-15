{ config, pkgs, lib, ... }:

{
  ##########################################################################
  ## System
  ##########################################################################
  system.stateVersion = "25.11";

  sdImage.compressImage = false;

  ##########################################################################
  ## Networking
  ##########################################################################
  networking = {
    hostName = "myoboku";
    # DHCP en todas las interfaces (ethernet por cable al router)
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 80 3000 8082 8200 ];
      allowedUDPPorts = [ 53 1900 ];
    };
  };

  ##########################################################################
  ## Locale / Time
  ##########################################################################
  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";

  ##########################################################################
  ## Users
  ##########################################################################
  users.users.wizord = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nixos";  # Cambiar con `passwd` tras primer login
    openssh.authorizedKeys.keys = [
      # Pon aquí tu clave pública SSH para acceder sin password
      # "ssh-ed25519 AAAA..."
    ];
  };

  ##########################################################################
  ## Services
  ##########################################################################

  # Mostrar IP en pantalla de login
  services.getty.helpLine = ''
    IP: \4
  '';

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;  # TODO: desactivar cuando metas tu clave SSH
    };
  };

  # Adguard Home (bloqueo DNS tipo Pi-hole, nativo NixOS)
  # mutableSettings = false  → Nix manda; la UI se resetea en cada arranque.
  # Reglas custom versionadas en ./adguard-userrules.txt
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    mutableSettings = false;
    settings = {
      http.address = "0.0.0.0:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [ "1.1.1.1" "8.8.8.8" ];
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          "2620:fe::10"
          "2620:fe::fe:10"
        ];
      };
      filters = [
        {
          enabled = true;
          id = 1;
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
        }
        {
          enabled = true;
          id = 2;
          name = "AdAway Default Blocklist";
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
        }
      ];
      # Cliente con filtering desactivado (bypass de AdGuard)
      clients.persistent = [
        {
          name = "hades";
          ids = [ "14:13:33:69:fd:67" ];
          uid = "019d7dd9-f8ff-7bfc-9b7e-d0fbe396fb6e";
          use_global_settings = true;
          filtering_enabled = false;
          parental_enabled = false;
          safebrowsing_enabled = false;
          use_global_blocked_services = true;
          tags = [];
          upstreams = [];
        }
      ];
      filtering.filtering_enabled = true;
      filtering.protection_enabled = true;
      # Custom filtering rules (los `!` son comentarios y se conservan como
      # cabeceras de sección en la UI de AdGuard).
      user_rules = lib.filter
        (s: s != "")
        (lib.splitString "\n" (builtins.readFile ./adguard-userrules.txt));
    };
  };

  ##########################################################################
  ## Homepage (dashboard único con todos los servicios)
  ## URL: http://192.168.178.24:8082
  ##########################################################################
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    # Homepage v0.9+ exige el Host header en la allowlist
    allowedHosts = "myoboku:8082,192.168.178.24:8082,localhost:8082,127.0.0.1:8082";

    settings = {
      title = "myoboku homelab";
      theme = "dark";
      color = "slate";
      headerStyle = "boxed";
      layout = {
        Red = { style = "row"; columns = 2; };
      };
    };

    services = [
      {
        Red = [
          { "AdGuard Home" = {
              href = "http://192.168.178.24:3000";
              description = "DNS adblock";
              icon = "adguard-home.png";
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

  # TODO: descomentar cuando tengas cargador bueno + disco

  # # MiniDLNA - arranca aunque el disco no esté montado
  # services.minidlna = {
  #   enable = true;
  #   openFirewall = true;
  #   settings = {
  #     friendly_name = "myoboku";
  #     media_dir = [ "/mnt/media" ];
  #     inotify = "yes";
  #   };
  # };

  # # Samba - compartir archivos por red
  # services.samba = {
  #   enable = true;
  #   openFirewall = true;
  #   settings = {
  #     global = {
  #       "workgroup" = "WORKGROUP";
  #       "server string" = "myoboku";
  #       "security" = "user";
  #     };
  #     media = {
  #       "path" = "/mnt/media";
  #       "browseable" = "yes";
  #       "read only" = "no";
  #       "valid users" = "wizord";
  #     };
  #   };
  # };

  # # Transmission - torrent con web UI
  # services.transmission = {
  #   enable = true;
  #   openFirewall = true;
  #   settings = {
  #     download-dir = "/mnt/media/descargas";
  #     incomplete-dir = "/mnt/media/descargas/.incomplete";
  #     rpc-bind-address = "0.0.0.0";
  #     rpc-whitelist-enabled = false;
  #   };
  # };

  # # Mount del disco externo (nofail = arranca sin él)
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-label/MEDIA";
  #   fsType = "ext4";
  #   options = [ "nofail" "x-systemd.device-timeout=5s" ];
  # };

  ##########################################################################
  ## Packages
  ##########################################################################
  environment.systemPackages = with pkgs; [
    vim
    htop
    git
    ranger
    fastfetch
    libraspberrypi  # vcgencmd para diagnóstico (throttling, voltaje, etc.)
  ];

  # Zsh + Oh My Zsh
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "dst";
      plugins = [ "git" "sudo" ];
    };
  };
  users.defaultUserShell = pkgs.zsh;

  # Watchdog: reinicio automático si el sistema se cuelga
  systemd.settings.Manager.RuntimeWatchdogSec = "30s";
  systemd.settings.Manager.RebootWatchdogSec = "60s";

  # Optimización para RPi 3 (1GB RAM)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Desactivar cosas innecesarias para RPi 3
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;

  # Filesystems innecesarios
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.supportedFilesystems.cifs = lib.mkForce false;
  boot.supportedFilesystems.ntfs = lib.mkForce false;
  boot.supportedFilesystems.btrfs = lib.mkForce false;
  boot.supportedFilesystems.xfs = lib.mkForce false;
  boot.supportedFilesystems.reiserfs = lib.mkForce false;

  # Sin escritorio/gráficos
  security.polkit.enable = false;
  services.udisks2.enable = false;
  xdg.portal.enable = false;
  # Ahorro de recursos
  programs.command-not-found.enable = false;
  services.logrotate.enable = false;
  services.lvm.enable = false;
  hardware.bluetooth.enable = false;

  # Nix más ligero
  nix.settings.trusted-users = [ "root" "wizord" ];
  nix.settings.require-sigs = false;
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--max-freed 1G";
  };

  # Máximo 4 generaciones
  boot.loader.generic-extlinux-compatible.configurationLimit = 4;

}
