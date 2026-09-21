{
  description = "NixOS de wizord: hades (portátil) + korriban (server) + hoth (padres) + emulador (rpi3)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      mkHost = import ./lib/mkHost.nix { inherit nixpkgs inputs; };
    in
    {
      nixosConfigurations = {
        hades = mkHost { host = "hades"; };
        korriban = mkHost { host = "korriban"; };
        # Portátil blanco de mis padres (XFCE). Actualiza solo desde GitHub.
        hoth = mkHost { host = "hoth"; };
        # Raspberry Pi 3 (aarch64) para emulación retro. Imagen SD:
        #   nix build .#nixosConfigurations.emulador.config.system.build.sdImage
        emulador = mkHost { host = "emulador"; system = "aarch64-linux"; };
      };
    };
}
