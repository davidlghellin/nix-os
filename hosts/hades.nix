{ pkgs, ... }:

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

  # CLI `sail` baseline (cacheado).
  # Solo los comandos; los servicios always-on son cosa de korriban (sail.nix).
  environment.systemPackages = [ pkgs.unstable.sail ];
}
