{ pkgs, ... }:

##############################################################################
## SAIL SIMD — variante OPCIONAL de sail compilada con target-cpu=native.
##
## NO se importa por defecto en ningún host: importarlo obliga a korriban a
## COMPILAR sail desde fuente (proyecto Rust grande → tarda y consume RAM),
## porque target-cpu=native rompe el uso de la caché binaria.
##
## Para activarlo, añade a los imports del host que quieras:
##     ../modules/sail-simd.nix
## y haz el rebuild. Aporta el CLI `sail-simd` en el PATH, junto al `sail`
## baseline (cacheado) de modules/sail.nix. Los servicios always-on siguen
## usando el baseline; esto es solo para pruebas/benchmark manual.
##
## OJO: `native` = la CPU que COMPILA. Como korriban hace su propio rebuild,
## apunta a su CPU; no copies este store path a una máquina con CPU más vieja
## (podría dar "illegal instruction").
##############################################################################
let
  # Misma fuente que el sail de nixpkgs, pero con SIMD (AVX2/AVX-512…): LLVM
  # auto-vectoriza mucho más para un motor Arrow/DataFusion como sail.
  sailSimd = pkgs.unstable.sail.overrideAttrs (old: {
    pname = "sail-simd";

    # NUNCA traer este binario de una caché: el hash del store path es idéntico
    # lo compile la CPU que lo compile (Nix no "ve" target-cpu=native), pero el
    # binario de dentro depende de la CPU. Sin esto, otra máquina podría hacer
    # substitute de este mismo hash y recibir instrucciones que su CPU no
    # soporta → "illegal instruction". Forzamos build local siempre.
    allowSubstitutes = false;

    env = (old.env or {}) // {
      # `native` = "TODO lo que tiene la CPU que COMPILA". Máximo rendimiento,
      # pero el binario solo es seguro en esa misma máquina o el mismo modelo de
      # CPU (o uno superset). En una más vieja/distinta que le falte alguna
      # feature → "illegal instruction". Por eso NO se debe compartir por caché
      # (ver allowSubstitutes abajo). Si algún día quieres compilar una vez y
      # repartir el binario entre varias máquinas, cambia `native` por un suelo
      # portable: `x86-64-v3` (AVX2) o `x86-64-v4` (AVX-512). (La RPi es ARM →
      # otra arquitectura, estos flags no aplican.)
      RUSTFLAGS = (old.env.RUSTFLAGS or "") + " -C target-cpu=native";
    };
  });

  # Se expone como `sail-simd` para convivir con el `sail` baseline en el PATH.
  # (Ambos binarios se llaman `sail` por dentro; el subcomando va por args, así
  # que el nombre del symlink es indiferente para el CLI.)
  sailSimdCli = pkgs.runCommand "sail-simd-cli" { } ''
    mkdir -p $out/bin
    ln -s ${sailSimd}/bin/sail $out/bin/sail-simd
  '';
in
{
  environment.systemPackages = [ sailSimdCli ];
}
