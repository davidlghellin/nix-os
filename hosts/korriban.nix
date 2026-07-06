{ ... }:

##############################################################################
## Korriban — el server (headless homelab).
## Solo cosas de server: red + SSH (common) + servicios (server) + GPU AMD
## para el transcoding de Jellyfin. Sin escritorio.
##############################################################################
{
  imports = [
    ../modules/common.nix
    ../modules/server.nix
    ../modules/media.nix
    ../modules/gpu-amd.nix
    ../modules/sail.nix
  ];

  networking.hostName = "Korriban";
}
