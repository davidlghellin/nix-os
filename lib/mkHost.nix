##############################################################################
## mkHost — arma un host a partir de hosts/<host>/.
##
## - `inputs` llega a todos los módulos vía specialArgs (common.nix lo usa
##   para el overlay de unstable y para nixPath/registry).
## - NO se pasa `pkgs` a nixosSystem: `nixpkgs.config` y `nixpkgs.overlays`
##   los sigue configurando common.nix, así los módulos no cambian.
##############################################################################
{ nixpkgs, inputs }:

{ host, system ? "x86_64-linux", extraModules ? [ ] }:

nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  modules = [
    (../hosts + "/${host}")
    # Estampa el commit del repo en el sistema: `nixos-version --json`
    # dice de qué commit viene lo que corre ("dirty" si había cambios sin commitear).
    { system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null; }
  ] ++ extraModules;
}
