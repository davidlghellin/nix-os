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
      allowedTCPPorts = [ 22 53 80 3000 8200 ];
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
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    settings = {
      http.address = "0.0.0.0:80";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };

  # MiniDLNA - arranca aunque el disco no esté montado
  services.minidlna = {
    enable = true;
    openFirewall = true;
    settings = {
      friendly_name = "myoboku";
      media_dir = [ "/mnt/media" ];
      inotify = "yes";
    };
  };

  # Mount del disco externo (nofail = arranca sin él)
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-label/MEDIA";  # Cambia por la label/UUID de tu disco
    fsType = "ext4";  # Cambia si es otro formato
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  ##########################################################################
  ## Packages
  ##########################################################################
  environment.systemPackages = with pkgs; [
    vim
    htop
    git
    ranger
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
