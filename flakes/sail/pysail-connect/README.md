# sail-pysail-connect

Cliente de [Sail](https://github.com/lakehq/sail) con **auto-detección**:

- Si hay un **server Spark Connect ya escuchando** (p.ej. el systemd de `korriban:50051`) → lo **reusa**.
- Si **no hay ninguno** → arranca un **server pysail EMBEBIDO** en tu proceso (fallback autocontenido).

Así el mismo entorno vale en korriban (reusa el systemd) y en el portátil sin server (se lo monta solo).

- API: DataFrame de Spark. **Sin Java** (motor Rust de Sail vía pysail).
- Deps por **nixpkgs**, sin pip ni venv.
- Entorno con [numtide/devshell](https://github.com/numtide/devshell): al entrar verás un **menú** de comandos (`menu` para reimprimirlo).

## Config

Server externo a probar (por defecto `localhost:50051`):

    export SAIL_HOST=korriban     # o 192.168.1.180
    export SAIL_PORT=50051

## Lanzar

    nix develop        # o `direnv allow` (hay .envrc con `use flake`); imprime el menú
    smoke              # reusa externo o arranca embebido, y hace SELECT 1
    tests              # pytest -v
    menu               # vuelve a mostrar el menú

## Estructura

    flake.nix          entorno Nix (python313 + pysail + pyspark + deps, devshell)
    src/session.py     get_session() -> (spark, server, mode)  [external | embedded]
    src/dataframes.py  función de ejemplo (suma_columnas)
    src/smoke.py       prueba de conexión
    tests/conftest.py  fixture `spark` (reusa externo o embebido)
    tests/             tests que usan el fixture
