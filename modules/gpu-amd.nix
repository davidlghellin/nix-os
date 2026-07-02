{ config, pkgs, ... }:

{
  ##########################################################################
  ## AMD Configuration (APUs/GPUs Radeon, p.ej. Radeon 680M en Rembrandt)
  ##########################################################################

  # Driver de Xorg/Wayland (amdgpu va por kernel; modesetting funciona, pero
  # lo dejamos explícito para descartar fallback a modesetting genérico).
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Base de aceleración gráfica. En el server (headless, sin desktop.nix) esto
  # es lo que habilita VAAPI para el transcoding por hardware de Jellyfin.
  hardware.graphics.enable = true;

  # Drivers VAAPI para aceleración de vídeo (decoder/encoder por hardware).
  # Mesa ya provee radeonsi_drv_video.so; estos paquetes añaden el puente
  # VDPAU<->VAAPI por si alguna app lo pide.
  hardware.graphics.extraPackages = with pkgs; [
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  # Utilidades para diagnóstico de GPU/VAAPI.
  environment.systemPackages = with pkgs; [
    libva-utils   # vainfo
    radeontop
  ];
}
