{ ... }:

##############################################################################
## Plantilla para una máquina nueva. Base mínima: red, SSH, shell y CLI.
##
## NO es un fallback: con flakes cada host es un output explícito y no hay
## dispatcher que elija por hostname. Para usarla, copia esto a
## hosts/<nombre>/default.nix, añade su hardware.nix y una línea en flake.nix.
##############################################################################
{
  imports = [
    ../modules/common.nix
  ];
}
