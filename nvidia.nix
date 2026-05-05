{ config, pkgs, ... }:

{
  ##########################################################################
  ## NVIDIA Configuration (laptops with Intel + NVIDIA)
  ##########################################################################

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = false;
    nvidiaSettings = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Kernel params para NVIDIA + Wayland
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];

  # Driver de aceleración de vídeo específico de NVIDIA
  # (la base de hardware.graphics está en configuration.nix)
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];

  # Script para lanzar Steam con NVIDIA
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "steam-nvidia" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec steam "$@"
    '')
  ];
}
