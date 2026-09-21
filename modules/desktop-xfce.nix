{ pkgs, ... }:

##############################################################################
## ESCRITORIO LIGERO (XFCE + LightDM) para equipos viejos o de otra gente.
## Alternativa a desktop.nix, NO a la vez: aquel es Hyprland/niri con los
## dotfiles de wizord; esto es barra + menú de toda la vida y funciona tal
## cual, sin stow. Idioma y zona horaria ya los pone common.nix.
##
## Lo que ya trae el módulo de XFCE (no repetir aquí): Thunar, Mousepad,
## Ristretto (fotos), Parole (vídeo), pavucontrol + plugin de volumen,
## nm-applet y udisks2/gvfs (pinchos USB). Sin impresoras.
##############################################################################
{
  ##########################################################################
  ## Sesión gráfica
  ##########################################################################
  services.xserver = {
    enable = true;
    xkb.layout = "es";
    desktopManager.xfce.enable = true;
    displayManager.lightdm.enable = true;
  };
  services.displayManager.defaultSession = "xfce";

  programs.thunar.plugins = with pkgs; [
    thunar-archive-plugin        # "Extraer aquí" con el botón derecho
    thunar-volman                # abre el pincho al enchufarlo
  ];

  ##########################################################################
  ## Hardware
  ##########################################################################
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;     # applet de bluetooth (XFCE no trae)

  # Equipo con poca RAM: swap comprimido en memoria, mucho más rápido que
  # tirar de disco cuando el navegador se come todo.
  zramSwap.enable = true;

  ##########################################################################
  ## Programas
  ##########################################################################
  environment.systemPackages = with pkgs; [
    unstable.brave               # mismos navegadores que desktop.nix, de unstable
    unstable.librewolf
    libreoffice-still
    hunspellDicts.es_ES          # corrector de LibreOffice en español
    vlc
    atril                        # PDF
    xarchiver                    # zip/rar (lo usa thunar-archive-plugin)
    galculator
    xfce4-whiskermenu-plugin     # menú de inicio con buscador, tipo Windows
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    liberation_ttf               # métricas de Arial/Times: los .docx se ven bien
  ];
}
