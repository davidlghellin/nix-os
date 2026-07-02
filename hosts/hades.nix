{ ... }:

##############################################################################
## hades — portátil con escritorio.
## common + desktop. Descomenta el módulo de GPU que corresponda.
##############################################################################
{
  imports = [
    ../modules/common.nix
    ../modules/desktop.nix
    ../modules/media.nix          # Jellyfin/Transmission/MiniDLNA a mano en el portátil
    ../modules/gpu-nvidia.nix     # NVIDIA (ajusta los BusId dentro)
    # ../modules/gpu-amd.nix      # si tiene APU/GPU AMD
  ];

  networking.hostName = "hades";
}
