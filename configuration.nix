{ config, pkgs, ... }:

{
  ##########################################################################
  ## Imports
  ##########################################################################
  imports = [
    ./hardware-configuration.nix
  ];

  ##########################################################################
  ## Boot
  ##########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ##########################################################################
  ## Networking
  ##########################################################################
  networking = {
    hostName = "hades";
    networkmanager.enable = true;
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
  services.xserver.enable = false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.niri.enable = true;

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
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
  };

  ##########################################################################
  ## Users
  ##########################################################################
  users.users.wizord = {
    isNormalUser = true;
    description = "David López";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "storage"
      "plugdev"
      "input"
      "video"
      "seat"
      "docker"
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
  ## GTK Theme (Minimalista)
  ##########################################################################
  environment.variables = {
    GTK_THEME = "Nordic";
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

    ## Bluetooth
    bluez
    bluez-tools
    blueman

    ## Network / VPN
    networkmanager
    networkmanagerapplet
    protonvpn-gui

    ## Apps
    brave
    firefox
    telegram-desktop
    obsidian
    libreoffice-qt6-fresh
    calibre
    vesktop
    xfce.thunar
    xfce.thunar-volman
    udiskie
    radiotray-ng

    ## Temas (Minimalista)
    nordic
    papirus-icon-theme
    bibata-cursors

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
    docker
    meld
    dbeaver-bin
    zathura
    glogg
    klavaro

    ## Productivity
    watson
  ];

  ##########################################################################
  ## Udev
  ##########################################################################
  services.udev.packages = [ pkgs.calibre ];

  ##########################################################################
  ## Minidlna
  ##########################################################################
  services.minidlna = {
    enable = true;
    settings = {
      media_dir = [ "V,/home/wizord/multimedia/Torrents" ];
      friendly_name = "Nixos Server";
      inotify = "yes";
      notify_interval = 900;
      port = 8200;
      network_interface = "wlp2s0";
    };
  };

  users.users.minidlna.extraGroups = [ "users" "wizord" ];

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

  ##########################################################################
  ## Nix
  ##########################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  ##########################################################################
  ## State version
  ##########################################################################
  system.stateVersion = "25.05";
}
