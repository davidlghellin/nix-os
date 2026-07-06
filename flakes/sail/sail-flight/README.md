# sail-flight

Cliente **Arrow Flight SQL** para [Sail](https://github.com/lakehq/sail) vía **ADBC**,
contra un server que **ya está corriendo** (p.ej. el servicio systemd en `korriban:32010`).

- API: **SQL** + tablas **Arrow** (no la API de DataFrames de Spark).
- El cliente **más ligero**: solo `pyarrow` + `adbc-driver-flightsql`. **Sin pyspark, sin pandas, sin Java.**
- Deps por **nixpkgs**, sin pip ni venv.
- Entorno con [numtide/devshell](https://github.com/numtide/devshell): al entrar verás un **menú** de comandos (`menu` para reimprimirlo).

## Requisito

Un server Arrow Flight SQL escuchando. Por defecto `grpc://korriban:32010`; cámbialo con:

    export FLIGHT_SQL_URI=grpc://192.168.1.180:32010

Si el handshake `grpc://` fallara, prueba `grpc+tcp://...`. Arrancar el server con sail:

    sail flight server --ip 0.0.0.0 --port 32010

## Lanzar

    nix develop        # o `direnv allow` (hay .envrc con `use flake`); imprime el menú
    smoke              # prueba rápida: SELECT 1
    tests              # pytest -v
    menu               # vuelve a mostrar el menú

## Estructura

    flake.nix          entorno Nix (python313 + pyarrow + adbc, devshell)
    src/queries.py     helpers connect() / query() -> pyarrow.Table
    src/smoke.py       prueba de conexión
    tests/conftest.py  fixture `conn` (ADBC, contra FLIGHT_SQL_URI)
    tests/             tests que usan el fixture
