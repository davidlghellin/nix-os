{ lib, ... }:

##############################################################################
## Dispatcher. Symlinkeado desde /etc/nixos/configuration.nix.
##
## Elige la config según el hostname de la máquina (/etc/hostname):
##   - hosts/<hostname>.nix   (en minúsculas: "Korriban" → hosts/korriban.nix)
##   - hosts/default.nix      si no existe una para este equipo (fallback)
##
## Así NO hay ningún fichero de selección sin trackear: la lista de módulos
## de cada máquina vive en git (hosts/*.nix). El único fichero per-máquina
## que queda fuera del repo es /etc/nixos/hardware-configuration.nix,
## que es autogenerado (nixos-generate-config) y único de cada equipo.
##############################################################################
let
  hostName = lib.toLower (lib.removeSuffix "\n" (builtins.readFile /etc/hostname));
  hostFile = ./hosts + "/${hostName}.nix";
  chosenHost = if builtins.pathExists hostFile then hostFile else ./hosts/default.nix;
in
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    chosenHost
  ];
}
