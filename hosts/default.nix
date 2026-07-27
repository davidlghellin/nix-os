{ ... }:

##############################################################################
## PLANTILLA para una máquina nueva. Este fichero NO se evalúa: nadie lo
## importa (mkHost solo resuelve hosts/<host>), es para copiar y rellenar.
## Por eso los paths están escritos para su DESTINO, hosts/<nombre>/default.nix.
##
##   1. mkdir hosts/<nombre> && cp hosts/default.nix hosts/<nombre>/default.nix
##   2. sudo cp /etc/nixos/hardware-configuration.nix hosts/<nombre>/hardware.nix
##   3. git add hosts/<nombre>        # el flake solo ve ficheros trackeados
##   4. en flake.nix:  <nombre> = mkHost { host = "<nombre>"; };
##   5. nixos-rebuild build --flake .#<nombre>   (y luego switch)
##
## NO es un fallback: con flakes cada host es un output explícito, no hay
## dispatcher que elija módulos por hostname.
##############################################################################
{
  imports = [
    ./hardware.nix                  # lo genera nixos-generate-config
    ../../modules/common.nix        # red, SSH, zsh + alias, CLI, nix.settings, boot

    ## Descomenta lo que use la máquina:
    # ../../modules/desktop.nix     # Hyprland/niri + SDDM + pipewire (equipo con pantalla)
    # ../../modules/server.nix      # servicios always-on del homelab
    # ../../modules/media.nix       # Jellyfin / Transmission / MiniDLNA
    # ../../modules/gpu-nvidia.nix  # NVIDIA — ajusta dentro los BusId (lspci) de tu equipo
    # ../../modules/gpu-amd.nix     # AMD, APU o dedicada
    # ../../modules/sail.nix        # servicios de Sail (LakeSail)

    ## ¿El equipo es para otra persona? wizord ya viene de common.nix como
    ## admin (wheel → sudo), así que puedes entrar a arreglar cosas. Añade
    ## encima el usuario que lo vaya a usar, que NO lleva wheel:
    # (import ../../lib/mkUser.nix {
    #   nombre = "david";
    #   descripcion = "David";
    #   paquetes = p: [ p.firefox p.vlc ];   # a su perfil, no al sistema
    # })
    ## Luego, una vez arrancado:  sudo passwd david
  ];

  networking.hostName = "CAMBIAME";

  # Versión con la que se INSTALA la máquina, no la que corre hoy: se pone una
  # vez y no se toca nunca más. common.nix deja 25.05 con mkDefault (es cuando
  # se instalaron hades y korriban); un equipo nuevo pone aquí la del ISO con
  # el que lo instales.
  system.stateVersion = "26.05";

  # Opcional: en modules/common.nix hay un `promptHostColor` que colorea el
  # hostname del prompt por máquina. Sin entrada propia sale en cian; añade la
  # tuya ahí si quieres distinguirla de un vistazo por SSH.
}
