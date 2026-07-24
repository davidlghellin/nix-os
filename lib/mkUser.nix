##############################################################################
## Crea un usuario "normal": el que USA el equipo pero no lo administra.
##
## `wizord` se declara en modules/common.nix, que lo importan todos los hosts,
## así que sigue siendo admin (grupo wheel → sudo) en cualquier máquina nueva
## sin tener que hacer nada. Esto es solo para añadir gente encima.
##
## Uso en hosts/<nombre>/default.nix:
##
##   imports = [
##     ../../modules/common.nix
##     ../../modules/desktop.nix
##     (import ../../lib/mkUser.nix {
##       nombre = "david";
##       descripcion = "David";
##       paquetes = p: [ p.firefox p.vlc ];   # solo para él, no para el sistema
##     })
##   ];
##
## Se puede importar varias veces con nombres distintos.
##
## Contraseña: NO se pone aquí (el repo está en GitHub). Tras el primer switch:
##
##   sudo passwd david
##
## USB / discos extraíbles: FUNCIONAN sin darle ningún grupo. Lo permite la
## política de udisks2, no los grupos: la acción
## org.freedesktop.udisks2.filesystem-mount tiene `allow_active = yes`, o sea
## que cualquier usuario sentado delante de la máquina (sesión local activa)
## monta un pincho sin contraseña. Los grupos "storage" y "plugdev" son
## vestigios que aquí no pintan nada (por SSH sí pediría auth: allow_inactive
## = auth_admin).
## Quien tiene que OFRECERLE montarlo es el escritorio, y hay dos vías:
##   - `udiskie` (automontaje + aviso): lo arranca la config del compositor, o
##     sea que necesita los dotfiles aplicados (`dots-apply`).
##   - `thunar` + `thunar-volman`: van en el sistema, le sale el pincho en la
##     barra lateral sin depender de los dotfiles.
##
## Dotfiles: la configuración de Hyprland/niri/waybar vive en dotfiles/ y se
## enlaza con stow al home de QUIEN lo ejecuta. Si el usuario nuevo va a usar
## el escritorio, entra como él y lanza el `dots-apply` (o le dejas el Hyprland
## por defecto, que arranca pero sin barra ni fondo).
##############################################################################
{ nombre
, descripcion ? nombre
  # DOS TIPOS DE USUARIO:
  #   admin = false (por defecto) → usa el equipo. Sin sudo, no monta discos.
  #   admin = true               → además administra: wheel (sudo) + discos USB.
  # Para alguien de confianza que quieras que se apañe solo, admin = true.
, admin ? false
, escritorio ? true      # grupos para poder usar la sesión gráfica
, red ? true             # puede cambiar de wifi desde el applet
, extraGroups ? [ ]
  # Paquetes SOLO para este usuario: van a su perfil, no a
  # environment.systemPackages. Se pasa como FUNCIÓN de pkgs:
  #
  #   paquetes = p: [ p.firefox p.vlc ];
  #
  # Función y no lista para no necesitar `pkgs` en la firma del host que lo
  # importa. (Una lista con `pkgs.firefox` también funciona —la evaluación es
  # perezosa y `pkgs` no se fuerza al resolver los `imports`— pero obliga al
  # fichero del host a declarar `{ pkgs, ... }`.)
, paquetes ? (_: [ ])
}:

{ config, pkgs, lib, ... }:

{
  users.users.${nombre} = {
    isNormalUser = true;
    description = descripcion;
    shell = pkgs.zsh;
    packages = paquetes pkgs;

    # Por defecto SIN "wheel": no administra la máquina. Tampoco "storage" ni
    # "plugdev" (no monta discos USB a mano). Con admin = true se le dan.
    extraGroups =
      lib.optionals admin [ "wheel" "storage" "plugdev" ]
      ++ lib.optionals red [ "networkmanager" ]
      ++ lib.optionals escritorio (
        [ "audio" "video" "input" ]
        # "seat" solo lo crea seatd, que entra con modules/desktop.nix. Sin
        # esta guarda, un host headless falla al activar (grupo inexistente).
        ++ lib.optional (config.users.groups ? seat) "seat"
      )
      ++ extraGroups;
  };
}
