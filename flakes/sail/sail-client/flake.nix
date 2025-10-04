{
  description = "Cliente Spark Connect mínimo (PySpark 3.5.x, sin Java)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
     system = "aarch64-darwin";
    #system = "x86_64-darwin"; # macOS; usa x86_64-linux si estás en Linux
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        python311
        python311Packages.pip
        python311Packages.virtualenv
      ];

      shellHook = ''
        # Prompt
        export PS1="\[\033[1;35m\](spark-connect) \[\033[1;32m\]\u@\h \[\033[1;34m\]\w \[\033[0m\]\$ "

        # Endpoint del Spark Connect server (ajústalo al tuyo)
        export SPARK_CONNECT_URL="''${SPARK_CONNECT_URL:-sc://localhost:50051}"

        # venv auto
        VENV_DIR="''\${VENV_DIR:-.venv}"
        if [ ! -d "''${VENV_DIR}" ]; then
          echo "🔧 Creando venv en ''${VENV_DIR} (Python 3.11)…"
          python3 -m venv "''${VENV_DIR}"
        fi
        . "''${VENV_DIR}/bin/activate"

        # pip tools al día
        python -m pip install --upgrade --disable-pip-version-check pip setuptools wheel >/dev/null

        # Solo cliente: PySpark (3.5.x), pandas y pyarrow para .toPandas()
        python -m pip install \
          "pyspark>=3.5,<4.1" \
          "pandas>=2,<3" \
          "pyarrow>=11,<16" \
          "grpcio>=1.62" \
          "grpcio-tools" \
          "grpcio-status"
        # alias de prueba rápida
        alias spark-connect-test='python - <<PY
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("''${SPARK_CONNECT_URL}").getOrCreate()
print("✅ Conectado a", "''${SPARK_CONNECT_URL}")
print(spark.sql("SELECT 1 AS ok").toPandas())
PY'

        echo
        echo "🔗 Spark Connect URL: ''${SPARK_CONNECT_URL}"
        echo "👉 Prueba: spark-connect-test"
        echo
      '';
    };
  };
}
