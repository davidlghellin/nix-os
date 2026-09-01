{ pkgs, ... }:

##############################################################################
## EMULADOR retro (RetroArch en kiosko).
##
## RetroArch arranca a pantalla completa al encender (vía `cage`, un
## compositor Wayland de un solo programa) → sensación de "consola".
##
## Las ROMs NO van en el repo (copyright + tamaño): viven en /home/wizord/roms
## y las copias tú por SSH/USB. RetroArch las encuentra desde su menú.
##############################################################################
let
  # RetroArch con los cores. Cada core cubre una(s) consola(s):
  #   genesis-plus-gx → Mega Drive / Master System / Game Gear
  #   mgba            → GBA / Game Boy / GBC
  #   nestopia        → NES
  #   snes9x          → SNES
  # Añadir más consolas = sumar su core aquí + su carpeta abajo.
  retroarch = pkgs.retroarch.withCores (cores: with cores; [
    genesis-plus-gx
    mgba
    nestopia
    snes9x
  ]);

  # Config declarativa forzada con --appendconfig (tiene prioridad sobre el
  # retroarch.cfg mutable del usuario, así sobrevive a reflasheos).
  #
  # video_driver = sdl2  → CLAVE en la RPi3: el driver `gl` (OpenGL de
  #   escritorio) CRASHEA (SIGSEGV en gl2_frame) porque la VideoCore IV solo
  #   tiene OpenGL ES. sdl2 renderiza estable.
  # fullscreen/windowed  → ocupa toda la pantalla (si no, sale en una esquina).
  retroarchCfg = pkgs.writeText "retroarch-emulador.cfg" ''
    video_driver = "sdl2"
    video_fullscreen = "true"
    video_windowed_fullscreen = "false"
    video_scale_integer = "false"
    input_joypad_driver = "udev"

    # Solo mandos (sin teclado): Start + Select abre/cierra el menú de
    # RetroArch. Combo 4 = Start+Select. Así se cambia de juego sin F1.
    input_menu_toggle_gamepad_combo = "4"

    # Sin ratón: no dibujar puntero en el menú (el cursor del compositor ya se
    # oculta con el tema transparente; esto quita también el de RetroArch).
    menu_mouse_enable = "false"
    input_overlay_show_mouse_cursor = "false"

    # Audio por ALSA directo a la salida HDMI (card 0 = vc4hdmi). RetroArch
    # venía con audio_driver=pulse, pero no hay PulseAudio → sin sonido.
    audio_driver = "alsathread"
    audio_device = "plughw:0,0"
  '';

  # Lanzador para el kiosko: RetroArch con la config forzada.
  launcher = pkgs.writeShellScript "emulador-retroarch" ''
    exec ${retroarch}/bin/retroarch --appendconfig=${retroarchCfg}
  '';

  # Genera las playlists de RetroArch (.lpl) desde ~/roms/<consola>/. Cada
  # consola → su core. El servicio de abajo lo ejecuta al arrancar y cada vez
  # que cambias algo en ~/roms → los juegos que copias por SSH aparecen SOLOS
  # en la lista del menú (tipo consola, sin escanear a mano).
  coreDir = "${retroarch}/lib/retroarch/cores";
  updatePlaylists = pkgs.writeShellScript "emulador-playlists" ''
    set -eu
    roms="$HOME/roms"; pl="$HOME/.config/retroarch/playlists"
    mkdir -p "$pl"
    gen() { # $1=carpeta $2=core.so $3=nombre-core $4=nombre-playlist
      local dir="$roms/$1" core="${coreDir}/$2" name="$3" out="$pl/$4.lpl"
      [ -d "$dir" ] || return 0
      local items="" first=1 f label
      for f in "$dir"/*; do
        [ -f "$f" ] || continue
        label="$(basename "$f")"; label="''${label%.*}"
        [ "$first" -eq 1 ] || items="$items,
"
        first=0
        items="$items    { \"path\": \"$f\", \"label\": \"$label\", \"core_path\": \"$core\", \"core_name\": \"$name\", \"crc32\": \"\", \"db_name\": \"$4.lpl\" }"
      done
      {
        printf '{\n  "version": "1.5",\n'
        printf '  "default_core_path": "%s",\n' "$core"
        printf '  "default_core_name": "%s",\n' "$name"
        printf '  "items": [\n%s\n  ]\n}\n' "$items"
      } > "$out"
    }
    gen megadrive    genesis_plus_gx_libretro.so "Genesis Plus GX" "Sega - Mega Drive - Genesis"
    gen mastersystem genesis_plus_gx_libretro.so "Genesis Plus GX" "Sega - Master System - Mark III"
    gen gamegear     genesis_plus_gx_libretro.so "Genesis Plus GX" "Sega - Game Gear"
    gen nes          nestopia_libretro.so        "Nestopia"        "Nintendo - Nintendo Entertainment System"
    gen snes         snes9x_libretro.so          "Snes9x"          "Nintendo - Super Nintendo Entertainment System"
    gen gb           mgba_libretro.so            "mGBA"            "Nintendo - Game Boy"
    gen gbc          mgba_libretro.so            "mGBA"            "Nintendo - Game Boy Color"
    gen gba          mgba_libretro.so            "mGBA"            "Nintendo - Game Boy Advance"
  '';

  # Tema de cursor TRANSPARENTE: oculta el puntero del ratón en el kiosko,
  # aunque haya un ratón conectado (cage lo dibuja si hay uno). Un cursor de
  # 1px transparente = invisible.
  blankCursor = pkgs.runCommand "blank-cursor-theme"
    { nativeBuildInputs = [ pkgs.xcursorgen pkgs.imagemagick ]; } ''
      mkdir -p $out/share/icons/blank/cursors
      magick -size 32x32 xc:transparent blank.png
      printf "32 0 0 blank.png\n" > blank.cfg
      xcursorgen blank.cfg $out/share/icons/blank/cursors/left_ptr
      cd $out/share/icons/blank/cursors
      for n in default arrow top_left_arrow xterm hand1 hand2 pointer watch left_ptr_watch; do
        ln -sf left_ptr "$n"
      done
      printf '[Icon Theme]\nName=blank\n' > $out/share/icons/blank/index.theme
    '';
in
{
  # Mesa/OpenGL para que RetroArch pinte por la GPU de la Pi (VideoCore).
  hardware.graphics.enable = true;

  # CLAVE en la RPi3: sube la memoria CMA (contigua) que usa la GPU V3D.
  # Con la CMA por defecto (~64MB) el driver vc4 se queda sin memoria
  # ("*ERROR* Failed to allocate from GEM DMA helper") → RetroArch peta o
  # sale a pantalla negra. Con 256MB va sobrado para 2D a 1080p.
  boot.kernelParams = [ "cma=256M" ];

  environment.systemPackages = [ retroarch ];

  # Grupos que necesita el usuario para GPU (video), mando (input) y sonido.
  users.users.wizord.extraGroups = [ "video" "input" "audio" ];

  # Carpetas de ROMs, una por consola (las llenas tú por SSH). Vacías al
  # principio; RetroArch escanea cada una y te arma una lista por consola en
  # el menú (sensación de "elige plataforma → elige juego").
  systemd.tmpfiles.rules = [
    "d /home/wizord/roms              0755 wizord users -"
    "d /home/wizord/roms/megadrive    0755 wizord users -"
    "d /home/wizord/roms/mastersystem 0755 wizord users -"
    "d /home/wizord/roms/gamegear     0755 wizord users -"
    "d /home/wizord/roms/nes          0755 wizord users -"
    "d /home/wizord/roms/snes         0755 wizord users -"
    "d /home/wizord/roms/gb           0755 wizord users -"
    "d /home/wizord/roms/gbc          0755 wizord users -"
    "d /home/wizord/roms/gba          0755 wizord users -"
  ];

  # Kiosko: `cage` lanza SOLO RetroArch a pantalla completa al arrancar,
  # gestionando pantalla (DRM/KMS), asiento y mandos. Sin escritorio.
  services.cage = {
    enable = true;
    user = "wizord";
    program = "${launcher}";
    # Cursor transparente → sin puntero de ratón a la vista.
    environment = {
      XCURSOR_THEME = "blank";
      XCURSOR_PATH = "${blankCursor}/share/icons";
    };
  };

  # Playlists autogeneradas: regenera al arrancar y vigila ~/roms (inotify),
  # así los juegos que copias por SSH aparecen solos en la lista del menú.
  systemd.services.emulador-playlists = {
    description = "Playlists de RetroArch autogeneradas desde ~/roms";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "wizord";
      Restart = "always";
      RestartSec = 2;
      ExecStart = pkgs.writeShellScript "emulador-playlists-watch" ''
        ${updatePlaylists}
        while ${pkgs.inotify-tools}/bin/inotifywait -r -e create,delete,moved_to,moved_from,close_write "$HOME/roms" >/dev/null 2>&1; do
          ${updatePlaylists}
        done
      '';
    };
  };
}
