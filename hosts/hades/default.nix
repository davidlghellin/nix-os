{ pkgs, ... }:

##############################################################################
## hades — portátil con escritorio.
## common + desktop. Descomenta el módulo de GPU que corresponda.
##############################################################################
{
  imports = [
    ./hardware.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/media.nix       # Jellyfin/Transmission/MiniDLNA a mano en el portátil
    ../../modules/gpu-nvidia.nix  # NVIDIA (ajusta los BusId dentro)
    # ../../modules/gpu-amd.nix   # si tiene APU/GPU AMD

    # Usuario de trabajo, con sudo (admin = true → wheel + storage + plugdev),
    # para que pueda administrar (nrs, montar discos) sin cambiar a wizord.
    #
    # CONTRASEÑA: no se pone aquí (el repo es público). Con mutableUsers = true
    # (el default) y sin hashedPassword, david nace BLOQUEADO. Tras el primer
    # `nrs` que lo cree, se le pone a mano una vez:
    #
    #     sudo passwd david
    #
    # A partir de ahí la contraseña persiste (no la gestiona el repo).
    #
    # ESCRITORIO: mkUser solo crea la cuenta; los dotfiles (waybar, fondo,
    # atajos…) se enlazan con stow al home de cada uno. Sin ellos, david entra
    # a un Hyprland pelado. Para tener el mismo entorno, entra como david y:
    #
    #     git clone <url-de-este-repo> ~/nix-os
    #     dots-apply          # enlaza los dotfiles; relogea para verlo
    (import ../../lib/mkUser.nix {
      nombre = "david";
      descripcion = "David — trabajo";
      admin = true;

      # Paquetes SOLO para david (a su perfil, no a todo el sistema). Se pasa
      # como función de pkgs. Descomenta y añade lo que necesite el trabajo:
      #
      # paquetes = p: [
      #   p.dbeaver-bin
      #   # p.unstable.<algo>   # si lo quieres desde unstable
      # ];
    })
  ];

  networking.hostName = "hades";

  # CLI `sail` baseline (cacheado).
  # Solo los comandos; los servicios always-on son cosa de korriban (sail.nix).
  environment.systemPackages = [ pkgs.unstable.sail ];
}
