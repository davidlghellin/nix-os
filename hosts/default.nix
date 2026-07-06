{ ... }:

##############################################################################
## Host por defecto (fallback).
## Se usa cuando /etc/hostname no coincide con ningún hosts/<nombre>.nix.
## Base mínima que arranca en cualquier hardware: red, SSH, shell y CLI.
## Ideal para una máquina de un solo uso: clonas, rebuild y listo.
##############################################################################
{
  imports = [
    ../modules/common.nix
  ];
}
