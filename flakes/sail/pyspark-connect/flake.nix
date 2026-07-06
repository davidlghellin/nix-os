{
  description = "Cliente Spark Connect para Sail — pyspark contra un server remoto (p.ej. korriban:50051)";

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
      # Entorno Python puro de nixpkgs (sin pip ni venv, sin líos de libstdc++).
      # pandas/pyarrow/grpcio NO son opcionales: el modo Spark Connect de pyspark
      # los exige en su check_dependencies() al importar.
      pyEnv = pkgs.python313.withPackages (ps: with ps; [
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
      # devshell → al entrar imprime un mensaje + el `menu` de comandos.
      default = pkgs.devshell.mkShell {
        name = "pyspark-connect";
        packages = [ pyEnv ];

        # Endpoint del server remoto. Override: export SPARK_REMOTE=... antes de entrar.
        env = [
          { name = "SPARK_REMOTE"; eval = "\${SPARK_REMOTE:-sc://korriban:50051}"; }
        ];

        commands = [
          { name = "smoke"; help = "prueba rápida: conecta y hace SELECT 1"; command = "python -m src.smoke"; }
          { name = "tests"; help = "pytest -v"; command = "pytest -v"; }
        ];

        devshell.motd = ''

          🔨 {bold}pyspark-connect{reset} — Spark Connect remoto (pyspark)
          server: $SPARK_REMOTE   (override con SPARK_REMOTE)
          $(menu)
        '';
      };
    });
  };
}
