{
  description = "NixOS de wizord: hades (portátil) + korriban (server)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
      };
    };
}
