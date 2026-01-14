# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #networking.hostName = "hades"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
networking = {
  hostName = "hades";
  networkmanager.enable = true;
#  nameservers = [ "192.168.1.184" "1.1.1.1" "8.8.8.8" ];  # Se usarán en ese orden
#  resolvconf.enable = true;
#  networkmanager.dns = "none";  # ¡Importante! para que no sobreescriba tus DNS
};

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
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


  # desactivar si estamos en wayland
   services.xserver.enable = false;
  # envidia driver -> puede que más consumo y ventilador
  #services.xserver.enable = true;
  #services.xserver.videoDrivers = [ "nvidia" ];
  #hardware.nvidia = {
  #  modesetting.enable = true;
  #  powerManagement.enable = true; # suspende/resume correcto
  #  open = false;                  # usa driver propietario en vez del open kernel module
  #  nvidiaSettings = true;         # panel de control nvidia-settings
  #};

  services.gvfs.enable = true;    # Necesario para Thunar / XFCE / Nautilus
  services.udisks2.enable = true;  # Permite montar USB, SD, discos, Kindle, etc.
  services.devmon.enable = true;  # monta automáticamente con udisks2


  services.displayManager.sddm.wayland.enable = true;

  services.displayManager.sddm.enable = true;

  services.seatd.enable = true;
  #services.blueman.enable = true;
  services.dbus.enable = true;

  #xdg.portal.enable = true;
  #xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];

xdg.portal = {
  enable = true;
  extraPortals = [
    pkgs.xdg-desktop-portal-gtk   # para diálogos, temas, etc.
    pkgs.xdg-desktop-portal-wlr   # para compositores Wayland como Niri o Hyprland
  ];

  # Prioriza el portal GTK si hay varios
  config.common.default = [ "gtk" "wlr" ];
};


  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };

# actualizar BIOS vía servicio
#services.fwupd.enable = true;

  # Configure console keymap
  console.keyMap = "es";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wizord = {
    isNormalUser = true;
    description = "David López";
#    shell = pkgs.zsh; 
    extraGroups = [ "networkmanager" "wheel" "storage" "plugdev" "input" "video" "seat" "docker"];
    packages = with pkgs; [
    ];
  };

  virtualisation.docker.enable = true;

  #programs.hyprland.enable = true;
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  # niri
  programs.niri.enable = true;

environment.sessionVariables = {
  # Electron/Chromium en Wayland
  NIXOS_OZONE_WL = "1";            # fuerza Wayland en Electron
  OZONE_PLATFORM = "wayland";      # pista adicional
  # Qt y GTK bien en Wayland (fallback a X11 si hace falta)
  QT_QPA_PLATFORM = "wayland;xcb";
  SDL_VIDEODRIVER = "wayland";
  CLUTTER_BACKEND = "wayland";
  # (opcional) Firefox en Wayland
  MOZ_ENABLE_WAYLAND = "1";
};

# Permite zsh como shell de login
environment.shells = with pkgs; [ zsh ];


programs.thunar.enable = true;

# Zsh + oh-my-zsh (todo declarativo)
programs.zsh = {
  enable = true;

  # Extras útiles
  autosuggestions.enable = true;
  syntaxHighlighting.enable = true;

  ohMyZsh = {
    enable = true;
    theme = "agnoster"; # "robbyrussell";   # cambia a "agnoster" o el que te guste
    plugins = [ "git" "docker" "kubectl" "sudo"];
  };

};
fonts.packages = with pkgs; [
  nerd-fonts.jetbrains-mono
  nerd-fonts.fira-code
  # o nerd-fonts.meslo-lg si prefieres Meslo
];

# Haz zsh la shell por defecto de tu usuario
users.users.wizord.shell = pkgs.zsh;

environment.shellInit = ''
  export PATH="$HOME/bin:$PATH"
'';

nix.settings.experimental-features = [ "nix-command" "flakes" ];



  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
	brightnessctl
	git
	kitty
	ranger
	yazi
	tig
	cmus
	fzf
	procs
	wget
	htop
	nitch
	fastfetch
	streamripper

	libnotify
	udiskie	
	waybar
	wlogout
	hyprshot
	hyprlock
	rofi
	swww
	eww
	hypridle
	pywal
	nwg-look
lsof
        wl-clipboard
	cliphist
	wl-clip-persist
	nwg-clipman
#lm_sensors

	# Apps
	brave
	firefox	
	# wayland
	fuzzel
	swaynotificationcenter
	# mako # notificaicoens simple
	pavucontrol
	blueman
	#gvfs
  gvfs
  udisks2

	# Alternativas Rust
	httpie
	xh
	dysk
	bat
	eza
	ripgrep
	fd
	btop


	# Audio	
	bluez
	bluez-tools
	pipewire
	wireplumber

	# Multimeda
	minidlna	
	mpv
	obs-studio
	radiotray-ng
	vlc
	yt-dlp
	telegram-desktop
	pulseaudio
	
	# otras
	calibre
	vesktop

    libreoffice-qt6-fresh   # KDE/Qt (recomendado en Qt)
  hunspell
  hunspellDicts.es_ES   # o hunspellDicts

	# desarrollo
	dbeaver-bin
  	docker
  	meld
  	neovim
  	vscode-fhs
  	# code
	zathura
	obsidian
	glogg
	klavaro

	gcc	
	openssl
	cacert
	pkg-config
	rustup
#	rustc
#	cargo
	protobuf
	python311
	maturin
	hatch
	lldb
	rust-analyzer


	protonvpn-gui
	protonmail-desktop
	proton-pass

  #protonmail-bridge
  #libappindicator

	xorg.xcursorthemes
	adwaita-icon-theme
  ];

services.udev.packages = [ pkgs.calibre ];


  # config para sail
  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE  = "24";

    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    PYTHON = "${pkgs.python311}/bin/python3";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

services.minidlna = {
  enable = true;
  settings = {
    media_dir = [ "V,/mnt/multimedia/Torrents" ];
    friendly_name = "Nixos Server";
    inotify = "yes";
    notify_interval = 900;
    port = 8200;
    network_interface = "wlp2s0";
  };
};

users.users.minidlna = {
    extraGroups =
      [ "users" "wizord" ];
  };

services.transmission = {
  enable = true;
  package = pkgs.transmission_4;

  user = "wizord";
  openFirewall = true;



  settings = {
    download-dir = "/mnt/multimedia/Torrents";
    incomplete-dir-enabled = false;

    # Acceso remoto (interfaz web)
    rpc-enabled = true;
    rpc-bind-address = "0.0.0.0";
    rpc-whitelist-enabled = false; # para acceder desde cualquier IP local

    # Permisos y ajustes básicos
    umask = 2; # permisos rw-rw-r--
    download-queue-enabled = true;
    download-queue-size = 5;
  };
};


networking.firewall = {
  enable = false;
  allowedTCPPorts = [ 51413  9091  8200 ]; # minidlna y transmission
  allowedUDPPorts = [ 51413 ];
  #allowedUDPPorts = [ 1900 ];      # SSDP de DLNA
};


  # networking.firewall.allowedTCPPorts = [ 8200 ];
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}

