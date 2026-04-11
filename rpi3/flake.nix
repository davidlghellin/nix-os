{
  description = "NixOS para Raspberry Pi 3 con Pi-hole";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware }: {
    nixosConfigurations.rpi3 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        nixos-hardware.nixosModules.raspberry-pi-3
        ./configuration.nix
      ];
    };

    # Para generar la imagen SD:
    # nix build .#images.rpi3
    images.rpi3 = self.nixosConfigurations.rpi3.config.system.build.sdImage;
  };
}
