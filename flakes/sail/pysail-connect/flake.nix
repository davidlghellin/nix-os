{
  description = "Cliente Sail — reusa el server externo (p.ej. korriban:50051) si está, si no arranca pysail EMBEBIDO. Sin Java.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, devshell }:
  let
    systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ devshell.overlays.default ];
      };
      # pysail trae el motor Rust (server embebido como fallback); pyspark es el
      # cliente. Deps puras de nixpkgs, sin pip ni venv. Sin Java.
      pyEnv = pkgs.python313.withPackages (ps: with ps; [
        pysail
        pyspark
        pandas
        pyarrow
        grpcio
        grpcio-status
        zstandard
        googleapis-common-protos
        pytest
      ]);
    in {
      default = pkgs.devshell.mkShell {
        name = "pysail-connect";
        packages = [ pyEnv ];

        # Server externo a reusar si está escuchando. Override antes de entrar.
        env = [
          { name = "SAIL_HOST"; eval = "\${SAIL_HOST:-localhost}"; }
          { name = "SAIL_PORT"; eval = "\${SAIL_PORT:-50051}"; }
        ];

        commands = [
          { name = "smoke"; help = "reusa server externo o arranca embebido + SELECT 1"; command = "python -m src.smoke"; }
          { name = "tests"; help = "pytest -v"; command = "pytest -v"; }
        ];

        devshell.motd = ''

          🔨 {bold}pysail-connect{reset} — reusa server externo o arranca pysail embebido
          externo a probar: sc://$SAIL_HOST:$SAIL_PORT   (si no escucha → embebido)
          $(menu)
        '';
      };
    });
  };
}
