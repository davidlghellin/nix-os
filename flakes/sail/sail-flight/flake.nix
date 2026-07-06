{
  description = "Cliente Arrow Flight SQL para Sail — ADBC/pyarrow contra un server remoto (p.ej. korriban:32010)";

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
      # El cliente más ligero de los tres: SIN pyspark ni pandas. Solo Arrow.
      # ADBC (Arrow Database Connectivity) habla Flight SQL de forma estándar.
      pyEnv = pkgs.python313.withPackages (ps: with ps; [
        pyarrow
        adbc-driver-flightsql
        adbc-driver-manager
        pytest
      ]);
    in {
      default = pkgs.devshell.mkShell {
        name = "sail-flight";
        packages = [ pyEnv ];

        # Endpoint. Si 'grpc://' fallara el handshake, prueba 'grpc+tcp://korriban:32010'.
        env = [
          { name = "FLIGHT_SQL_URI"; eval = "\${FLIGHT_SQL_URI:-grpc://korriban:32010}"; }
        ];

        commands = [
          { name = "smoke"; help = "prueba rápida: conecta y hace SELECT 1"; command = "python -m src.smoke"; }
          { name = "tests"; help = "pytest -v"; command = "pytest -v"; }
        ];

        devshell.motd = ''

          🔨 {bold}sail-flight{reset} — Arrow Flight SQL (ADBC, sin pyspark)
          server: $FLIGHT_SQL_URI   (override con FLIGHT_SQL_URI)
          $(menu)
        '';
      };
    });
  };
}
