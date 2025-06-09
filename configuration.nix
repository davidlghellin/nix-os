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
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  #services.connman.enable = true;
  networking.networkmanager.enable = true;


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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Enlightenment Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.enlightenment.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "es";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wizord = {
    isNormalUser = true;
    description = "wizord";
    shell = pkgs.zsh;
    extraGroups = [ "bluetooth" "networkmanager" "wheel" "docker"];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

virtualisation.docker.enable = true;

  # Install firefox.
  programs.firefox.enable = true;
  programs.hyprland.enable = true;
  programs.zsh.enable = true;



  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

environment.systemPackages = with pkgs; [
  # Terminal y herramientas de línea
  zsh
  kitty
  ranger
  tig
  git
  bat
  ripgrep
  cmus
  fd
  procs
  wget
  yt-dlp
  grim            # Screenshots
  slurp           # Seleccionar área para screenshot
  swappy          # Editor de capturas

  # Wayland y entorno gráfico
  waybar
  fuzzel
  #eww
  mako
  networkmanagerapplet
  wl-clipboard
  pavucontrol
  blueman

  # vpn para conf proton
  openvpn
  networkmanager
  networkmanager-openvpn

  # Audio
  pipewire
  wireplumber

  # multimedia
  vlc
  transmission_3-gtk
  obs-studio
  minidlna

  # desarrollo
  meld
  vscode-fhs
  # code
  neovim
  docker

  # otros
  calibre
  klavaro
];




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
# Para GUI de Bluetooth
services.blueman.enable = true;

services.minidlna = {
  enable = true;
  settings = {
    media_dir = [ "/mnt/media" ];  # Ajusta la ruta a donde tengas tus vídeos, música o fotos
    friendly_name = "Mi DLNA Server";
    inotify = "yes";
    notify_interval = 900;
    port = 8200;
network_interface = "ens18";
  };
};

services.transmission = {
  enable = true;
  settings = {
    rpc-enabled = true;
    rpc-port = 9091;
    rpc-whitelist-enabled = false; # cuidado con seguridad
    download-dir = "/home/wizord/Torrents";
  };
};



networking.useDHCP = false;

networking.interfaces.ens18.useDHCP = false;

networking.interfaces.ens18.ipv4.addresses = [{
  address = "192.168.1.10";  # ← cambia esto según tu red
  prefixLength = 24;          # 255.255.255.0
}];

networking.defaultGateway = "192.168.1.1";  # ← cambia si tu router usa otra IP
networking.nameservers = [ "192.168.1.194" "1.0.0.1" "8.8.8.8" ];  # Cloudflare y Google DNS

networking.networkmanager.dns = "none"; # evita que use DHCP para los DNS



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
