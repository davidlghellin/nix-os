{ config, pkgs, lib, ... }:

let
  # Configuración per-máquina. Cada equipo tiene su propio /etc/nixos/host.nix
  # (NO se sube al repo). Plantilla en host.nix.example.
  host =
    if builtins.pathExists /etc/nixos/host.nix
    then import /etc/nixos/host.nix
    else { hostname = "nixos"; hasNvidia = false; hasAmd = false; hasAdblock = false; };

  # Dominio local derivado del hostname (DNS en lowercase).
  # Genera URLs tipo http://jellyfin.korriban, http://torrents.korriban, etc.
  domain = lib.toLower host.hostname;
in
{
  ##########################################################################
  ## Imports
  ##########################################################################
  imports = [
    /etc/nixos/hardware-configuration.nix
  ] ++ lib.optional host.hasNvidia ./nvidia.nix
    ++ lib.optional host.hasAmd ./amd.nix;

  ##########################################################################
  ## Boot
  ##########################################################################
  # Cross-compile para Raspberry Pi 3 (aarch64)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;  # Limita las generaciones en el menú de boot
  boot.loader.efi.canTouchEfiVariables = true;

  # Prevent phantom /dev/dri/card0 from simpledrm (fixes gpu-screen-recorder)
  boot.blacklistedKernelModules = [ "simpledrm" ];

  # Módulos para lector de tarjetas SD
  boot.kernelModules = [ "sdhci" "sdhci_pci" ];

  # Plymouth (splash screen de arranque/apagado)
  boot.plymouth = {
    enable = true;
    theme = "bgrt";  # Tema minimalista con logo del fabricante
  };
  boot.initrd.systemd.enable = true;  # Necesario para Plymouth

  ##########################################################################
  ## Networking
  ##########################################################################
  networking = {
    hostName = host.hostname;
    networkmanager.enable = true;
    extraHosts = ''
      192.168.1.153 myoboku-mostoles
    '' + lib.optionalString host.hasAdblock ''
      127.0.0.1 jellyfin.${domain} torrents.${domain} adguard.${domain} dlna.${domain}
    '';
  };

  ##########################################################################
  ## Adblock local (AdGuard Home en 127.0.0.1)
  ## Web UI: http://localhost:3000  (primer arranque: crear usuario y listas)
  ##########################################################################
  services.adguardhome = lib.mkIf host.hasAdblock {
    enable = true;
    mutableSettings = true;  # permite cambios desde la web UI
    settings = {
      http.address = "127.0.0.1:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };

  networking.nameservers = lib.mkIf host.hasAdblock [ "127.0.0.1" ];
  networking.networkmanager.insertNameservers = lib.mkIf host.hasAdblock [ "127.0.0.1" ];

  ##########################################################################
  ## Caddy reverse proxy (URLs limpias para servicios locales)
  ## Solo en el server (hasAdblock = true).
  ## URLs:
  ##   http://jellyfin.${domain}  → :8096
  ##   http://torrents.${domain}  → :9091
  ##   http://adguard.${domain}   → :3000
  ##   http://dlna.${domain}      → :8200
  ## Para que resuelvan en la LAN:
  ##   1. Reservar IP fija de este host en el router.
  ##   2. AdGuard escuchando en LAN (bind_hosts = "0.0.0.0", abrir puerto 53).
  ##   3. AdGuard DNS Rewrites: *.${domain} → IP fija del host.
  ##   4. Router: repartir la IP del host como DNS por DHCP.
  ##########################################################################
  services.caddy = lib.mkIf host.hasAdblock {
    enable = true;
    virtualHosts."http://jellyfin.${domain}".extraConfig = "reverse_proxy localhost:8096";
    virtualHosts."http://torrents.${domain}".extraConfig = "reverse_proxy localhost:9091";
    virtualHosts."http://adguard.${domain}".extraConfig  = "reverse_proxy localhost:3000";
    virtualHosts."http://dlna.${domain}".extraConfig     = "reverse_proxy localhost:8200";
  };

  ##########################################################################
  ## Locale / Time
  ##########################################################################
  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "es_ES.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  console.keyMap = "es";

  ##########################################################################
  ## Hardware
  ##########################################################################
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  ##########################################################################
  ## Base Services
  ##########################################################################
  services = {
    dbus.enable = true;
    seatd.enable = true;

    gvfs.enable = true;      # Thunar / automount
    udisks2.enable = true;
    devmon.enable = true;

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
      };
    };
  };

  ##########################################################################
  ## Power Management (Batería)
  ##########################################################################
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      START_CHARGE_THRESH_BAT0 = 75;  # Empieza a cargar al 75%
      STOP_CHARGE_THRESH_BAT0 = 80;   # Para de cargar al 80% (alarga vida batería)
    };
  };

  ##########################################################################
  ## Audio (PipeWire)
  ##########################################################################
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  ##########################################################################
  ## Display / Wayland
  ##########################################################################
  services.xserver.enable = true;  # Necesario para xkb layout y carga de drivers de vídeo
  services.xserver.xkb.layout = "es";

  # Soporte gráfico (Vulkan + 32-bit para Steam/Wine, válido en Intel/AMD/NVIDIA)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      vulkan-loader
    ];
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "pixie";
    extraPackages = with pkgs; [
      kdePackages.qt5compat
      kdePackages.qtdeclarative
      kdePackages.qtsvg
    ];
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.niri.enable = true;

  ##########################################################################
  ## Polkit (Autenticación gráfica)
  ##########################################################################
  security.polkit.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  ##########################################################################
  ## XDG Portals (Wayland friendly)
  ##########################################################################
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  ##########################################################################
  ## Environment variables (Wayland sanity)
  ##########################################################################
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    OZONE_PLATFORM = "wayland";
    QT_QPA_PLATFORM = "wayland;xcb";
    CLUTTER_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
  };

  ##########################################################################
  ## Users
  ##########################################################################
  users.groups.media = {};  # Grupo compartido para servicios multimedia

  users.users.wizord = {
    isNormalUser = true;
    description = "David López";
    shell = pkgs.zsh;
    homeMode = "711";  # Permite a otros atravesar el directorio home
    extraGroups = [
      "wheel"
      "networkmanager"
      "storage"
      "plugdev"
      "input"
      "video"
      "seat"
      "docker"
      "media"
    ];
  };

  ##########################################################################
  ## Shell (Zsh)
  ##########################################################################
  environment.shells = with pkgs; [ zsh ];

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      cat = "bat -pp";
      vi = "nvim";
      vim = "nvim";
      ls = "eza --long --header";
      top = "btop";
      ".." = "cd ..";
      "..." = "cd ../..";
      df = "dysk";
      ports = "ss -tulnp";
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
      youtube = "yt-dlp -x --audio-format mp3 --audio-quality 0";
      flakenv = ''echo "use flake" > .envrc && direnv allow'';
      # wifi-scan → rescan + list
      # wifi-connect RED password "PASSSS"
      # wifi-connect RED --ask
      wifi-scan = "nmcli device wifi rescan && nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
    };

    interactiveShellInit = ''
      nrs() { sudo nixos-rebuild switch --upgrade |& nom; }
      RPROMPT='%F{yellow}%*%f'

      extract() {
        if [[ -z "$1" ]]; then
          echo "Uso: extract <archivo> [contraseña]"
          return 1
        fi
        if [[ ! -f "$1" ]]; then
          echo "Error: '$1' no existe"
          return 1
        fi
        local pass_arg=""
        [[ -n "$2" ]] && pass_arg="-p$2"
        if 7z x $pass_arg "$1" 2>/dev/null; then
          return 0
        fi
        if [[ "$1" == *.rar || "$1" == *.RAR ]]; then
          echo "7z falló, usando unrar..."
          NIXPKGS_ALLOW_UNFREE=1 nix-shell -p unrar --run "unrar x $pass_arg $1"
        else
          echo "Error: No se pudo extraer '$1'"
          return 1
        fi
      }
    '';

    ohMyZsh = {
      enable = true;
      theme = "agnoster";
      plugins = [ "git" "docker" "kubectl" "sudo" ];
    };
  };

  # PATH para scripts gestionados con stow (~/bin)
  environment.shellInit = ''
    export PATH="$HOME/bin:$PATH"
    export DIRENV_CONFIG="/etc/direnv"
  '';

  ##########################################################################
  ## direnv (auto-activa flake.nix / shell.nix al hacer cd)
  ##########################################################################
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = false;
  };

  # Oculta el listado de variables que direnv exporta al cargar el entorno
  environment.etc."direnv/direnv.toml".text = ''
    [global]
    hide_env_diff = true
  '';

  ##########################################################################
  ## Fonts
  ##########################################################################
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  ##########################################################################
  ## GTK/Qt Theme (Catppuccin Mocha)
  ##########################################################################
  environment.variables = {
    GTK_THEME = "catppuccin-mocha-blue-standard+default";
  };

  qt = {
    enable = true;
    platformTheme = "gtk2";
    style = "gtk2";
  };

  ##########################################################################
  ## Virtualisation
  ##########################################################################
  virtualisation.docker.enable = true;

  ##########################################################################
  ## System Packages
  ##########################################################################
  environment.systemPackages = with pkgs; [
    ## CLI / Utils
    git wget curl
    ripgrep fd eza bat
    fzf procs btop htop
    lsof
    stow

    # Archivos y datos
    tree
    jq
    zip
    unzip
    p7zip
    # Git / CLI extra
    gitui
    httpie
    xh
    dysk
    nitch
    fastfetch

    # Spellcheck
    hunspell
    hunspellDicts.es_ES

    ## Terminal / File managers
    kitty
    yazi

    ## Wayland / Desktop
    waybar
    rofi
    fuzzel
    wlogout
    hyprshot
    hyprlock
    hypridle
    hyprpanel
    swww
    eww
    nwg-look
    pywal
    brightnessctl
    playerctl
    xdg-desktop-portal-hyprland

    ## Screenshots
    grim
    slurp

    ## Polkit
    polkit_gnome

    ## Power Management
    powertop     # Diagnóstico de consumo
    acpi         # Info de batería

    ## Clipboard
    wl-clipboard
    cliphist
    wl-clip-persist
    nwg-clipman

    ## Audio / Media
    pipewire
    wireplumber
    pulseaudio
    pavucontrol
    cmus
    mpv
    vlc
    streamripper

    ## Notifications
    libnotify
    swaynotificationcenter

    ## OSD (On-Screen Display)
    swayosd

    ## Bluetooth
    bluez
    bluez-tools
    blueman

    ## Network / VPN
    networkmanager
    networkmanagerapplet

    ## Gaming / Wine
    winetricks

    ## Apps
    qalculate-gtk  # Calculadora para scratchpad
    obsidian
    libreoffice-qt6-fresh
    calibre
    vesktop
    xfce.thunar
    xfce.thunar-volman
    udiskie
    radiotray-ng

    ## Temas (Catppuccin Mocha)
    catppuccin-gtk
    catppuccin-cursors.mochaBlue
    tela-icon-theme
    colloid-icon-theme
    numix-icon-theme

    ## SDDM Theme
    (stdenv.mkDerivation {
      pname = "sddm-theme-pixie";
      version = "1.0.0";
      src = fetchFromGitHub {
        owner = "xCaptaiN09";
        repo = "pixie-sddm";
        rev = "730072544f3785c43eb05674c334a7d0fb07681b";
        sha256 = "sha256-1PDWX8bJfc0HYMW9MsxWwDXDoYy5aaehUWr7FW3yR9U=";
      };
      installPhase = ''
        mkdir -p $out/share/sddm/themes/pixie
        cp -r . $out/share/sddm/themes/pixie
        cp ${/home/wizord/Images/plant.jpg} $out/share/sddm/themes/pixie/assets/background.jpg
      '';
    })

    ## Dev
    gcc
    pkg-config
    openssl
    cacert
    rustup
    rust-analyzer
    protobuf
    python311
    hatch
    maturin
    neovim
    vscode-fhs
    meld
    dbeaver-bin
    zathura
    glogg
    klavaro

    ## Productivity
    watson

    ## Desde unstable para tener siempre la última versión
    unstable.brave
    unstable.claude-code
    unstable.firefox
    unstable.proton-vpn
    unstable.sail

    ## System
    nix-output-monitor
  ];

  ##########################################################################
  ## Udev
  ##########################################################################
  services.udev.packages = [ pkgs.calibre ];

  ##########################################################################
  ## Disco externo disk_dlg
  ##########################################################################
  fileSystems."/media/disk_dlg" = {
    device = "/dev/disk/by-uuid/d15c7085-bd18-4bc0-a0ef-963275396cd9";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.device-timeout=5s" ];
  };

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
      friendly_name = host.hostname;
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
  ## Firewall
  ## Para saber si un servicio soporta openFirewall:
  ##   nixos-option services.<nombre>.openFirewall
  ## MiniDLNA lo soporta, se podría quitar el puerto 8200 manual con:
  ##   services.minidlna.openFirewall = true;
  ##########################################################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8200 51413 ]
      ++ lib.optionals host.hasAdblock [ 80 53 ];  # Caddy + AdGuard DNS
    allowedUDPPorts = [ 51413 ]
      ++ lib.optionals host.hasAdblock [ 53 ];  # AdGuard DNS
  };

  ##########################################################################
  ## Steam
  ##########################################################################
  programs.steam.enable = true;

  ##########################################################################
  ## Rust (auto-fix rustup si está roto)
  ##########################################################################
  system.activationScripts.rustup-check = ''
    if ! /run/wrappers/bin/su wizord -c "${pkgs.rustup}/bin/rustup show active-toolchain" &>/dev/null; then
      echo "Rustup sin default configurado, configurando nightly..."
      /run/wrappers/bin/su wizord -c "${pkgs.rustup}/bin/rustup default nightly" || true
    fi
  '';

  ##########################################################################
  ## Nix
  ##########################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  programs.nix-ld = {
    enable = true;
  };

  # Garbage collection automático
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Overlay para paquetes de unstable
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
        config.allowUnfree = true;
      };
    })
  ];

  ##########################################################################
  ## State version
  ##########################################################################
  system.stateVersion = "25.05";
}
