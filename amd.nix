{ config, pkgs, ... }:

{
  ##########################################################################
  ## AMD Configuration (APUs/GPUs Radeon, p.ej. Radeon 680M en Rembrandt)
  ##########################################################################

  # Driver de Xorg/Wayland (amdgpu va por kernel; modesetting funciona, pero
  # lo dejamos explícito para descartar fallback a modesetting genérico).
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Drivers VAAPI para aceleración de vídeo (decoder/encoder por hardware).
  # Mesa ya provee radeonsi_drv_video.so; estos paquetes añaden el puente
  # VDPAU<->VAAPI por si alguna app lo pide.
  # (la base de hardware.graphics está en configuration.nix)
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
