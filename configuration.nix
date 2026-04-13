{ config, pkgs, ... }:

{
  ##########################################################################
  ## Imports
  ##########################################################################
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./nvidia.nix  # Comentar esta línea en PCs sin NVIDIA
  ];

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
    hostName = "hades";
    networkmanager.enable = true;
    extraHosts = ''
      192.168.1.153 myoboku-mostoles
    '';
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
  services.xserver.enable = true;  # Necesario para cargar drivers NVIDIA
  services.xserver.xkb.layout = "es";

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
    #SDL_VIDEODRIVER = "wayland,x11";
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

    ohMyZsh = {
      enable = true;
      theme = "agnoster";
      plugins = [ "git" "docker" "kubectl" "sudo" ];
    };
  };

  # PATH para scripts gestionados con stow (~/bin)
  environment.shellInit = ''
    export PATH="$HOME/bin:$PATH"
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
    yt-dlp

    # Git / CLI extra
    tig
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
    ranger
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
    yt-dlp
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
    protonvpn-gui

    ## Gaming / Wine
    winetricks

    ## Apps
    qalculate-gtk  # Calculadora para scratchpad
    brave
    firefox
    #telegram-desktop
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
        rev = "main";
        sha256 = "sha256-NkjWP/y3kLRjYM0Wr3l7ndbMx3XYxQFXy07C28vrUSU=";
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
    #docker
    meld
    dbeaver-bin
    zathura
    glogg
    klavaro

    ## Productivity
    watson

    ## Desde unstable para tener siempre la última versión
    unstable.claude-code
    unstable.sail
  ];

  ##########################################################################
  ## Udev
  ##########################################################################
  services.udev.packages = [ pkgs.calibre ];

  ##########################################################################
  ## Disco externo disk_dlg
  ##########################################################################
  fileSystems."/mnt/disk_dlg" = {
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
        "/mnt/disk_dlg"
      ];
      friendly_name = "Nixos Server";
      inotify = "yes";
      notify_interval = 900;
      port = 8200;
      network_interface = "wlp2s0";
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
      umask = 2;
      download-queue-enabled = true;
      download-queue-size = 5;
    };
  };

  ##########################################################################
  ## Firewall (abierto a propósito)
  ##########################################################################
  networking.firewall = {
    enable = false;
    allowedTCPPorts = [ 51413 8200 9091 ];
    allowedUDPPorts = [ 51413 ];
  };



programs.steam = {
  enable = true;
  package = pkgs.steam.override {
    extraArgs = "--enable-gpu --enable-gpu-compositing";
  };
};


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
