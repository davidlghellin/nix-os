# sail-pyspark-connect

Cliente **Spark Connect** para [Sail](https://github.com/lakehq/sail) con **pyspark**,
contra un server que **ya está corriendo** (p.ej. el servicio systemd en `korriban:50051`).

- API: DataFrame de Spark (`spark.createDataFrame`, `spark.sql(...)`, ...).
- Deps por **nixpkgs**, sin pip ni venv (y sin el lío de `libstdc++`).
  `pandas`/`pyarrow`/`grpcio` no son opcionales: pyspark connect los exige al importar.
- Sin Java: es cliente Connect, no un Spark local con JVM.
- Entorno con [numtide/devshell]: al entrar verás un **menú** de comandos (`menu` para reimprimirlo).

## Requisito

Un server Spark Connect escuchando. Por defecto `sc://korriban:50051`; cámbialo con:

    export SPARK_REMOTE=sc://192.168.1.180:50051

Si no tienes uno, arráncalo con el binario de sail:

    sail spark server --ip 0.0.0.0 --port 50051

## Lanzar

    nix develop        # o `direnv allow` (hay .envrc con `use flake`); imprime el menú
    smoke              # prueba rápida: SELECT 1
    tests              # pytest -v
    menu               # vuelve a mostrar el menú

## Estructura

    flake.nix          entorno Nix (python313 + pyspark + deps, devshell)
    src/dataframes.py  función de ejemplo (suma_columnas)
    src/smoke.py       prueba de conexión
    tests/conftest.py  fixture `spark` (contra SPARK_REMOTE)
    tests/             tests que usan el fixture
