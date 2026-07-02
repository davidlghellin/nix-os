{ config, pkgs, lib, ... }:

##############################################################################
## ESCRITORIO (Wayland: Hyprland + Niri, audio, batería, GUI apps).
## Se importa solo en máquinas con pantalla (p.ej. el portátil hades).
##############################################################################
{
  ##########################################################################
  ## Boot (cosas gráficas de arranque)
  ##########################################################################
  # Evita un /dev/dri/card0 fantasma de simpledrm (arregla gpu-screen-recorder)
  boot.blacklistedKernelModules = [ "simpledrm" ];

  # Plymouth (splash screen de arranque/apagado)
  boot.plymouth = {
    enable = true;
    theme = "bgrt";  # Tema minimalista con logo del fabricante
  };
  boot.initrd.systemd.enable = true;  # Necesario para Plymouth

  ##########################################################################
  ## Hardware
  ##########################################################################
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
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
  ## Desktop base services
  ##########################################################################
  services = {
    dbus.enable = true;
    seatd.enable = true;

    gvfs.enable = true;      # Thunar / automount
    udisks2.enable = true;
    devmon.enable = true;
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
  # La base hardware.graphics.enable la ponen también los módulos de GPU.
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
    config.common.default = [
      "hyprland"
      "gtk"
    ];
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
  ## Users (grupos extra de escritorio; se suman a los de common.nix)
  ##########################################################################
  users.users.wizord.extraGroups = [
    "input"
    "video"
    "seat"
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
  ## Udev
  ##########################################################################
  services.udev.packages = [ pkgs.calibre ];

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
  ## System Packages (escritorio + apps + dev)
  ##########################################################################
  environment.systemPackages = with pkgs; [
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
    libreoffice-qt6-fresh
    calibre
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
    python3
    hatch
    maturin
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
    unstable.firefox
    unstable.proton-vpn
    unstable.sail
  ];
}
