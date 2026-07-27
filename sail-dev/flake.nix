{
  description = "Sail — dev-shell (toolchain + comandos), desacoplado de la fuente";

  ##############################################################################
  ## Entorno de desarrollo de Sail para usar SIN mergear ni cambiarte a la rama
  ## dev/nix. Trae el toolchain (rust/cargo vía fenix, jdk17, protobuf, python,
  ## mold, sccache…) y los comandos `sail-*`.
  ##
  ## USO (direnv ya viene de common.nix):
  ##   cd ~/Proyectos/sail
  ##   echo "use flake ~/nix-os/sail-dev" > .envrc && direnv allow
  ## O a mano:  nix develop ~/nix-os/sail-dev
  ##
  ## El .envrc del checkout de sail es tuyo, no va al PR: exclúyelo en local con
  ##   echo .envrc >> ~/Proyectos/sail/.git/info/exclude
  ##
  ## Adaptación del dev-shell de la rama dev/nix (mismos inputs y flake.lock),
  ## afinada para uso local: versión de spark DINÁMICA (del checkout), fetch de
  ## pyspark autocontenido (último run de artifacts, sin pinear), tope de cores y
  ## un `sail-cli`. Los `sail-*` operan sobre $PRJ_ROOT (tu checkout de sail).
  ## Excepción: `sail-nix-build` hace `nix build .#pysail` y necesita el flake
  ## dentro del repo de sail (rama dev/nix); desde `main` no funciona.
  ##############################################################################

  # Mismos inputs que la rama dev/nix, y reutilizamos su flake.lock tal cual →
  # mismos store paths, reproducible y sin re-resolver nada.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, fenix, devshell }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };

        lib = pkgs.lib;
        isLinux = pkgs.stdenv.isLinux;

        fenixPkgs = fenix.packages.${system};
        rustToolchain = fenixPkgs.combine [
          fenixPkgs.stable.cargo
          fenixPkgs.stable.rustc
          fenixPkgs.stable.clippy
          fenixPkgs.stable.rust-src
          fenixPkgs.stable.rust-std
          fenixPkgs.stable.rust-analyzer
          fenixPkgs.latest.rustfmt
        ];

        # Build directo contra Python 3.13 (igual que la rama dev/nix). La suite
        # (sail-server-spark / sail-test-spark) usa el 3.11 del venv que fuerza
        # run-server.sh; alinear versiones NO evita que PyO3 recompile al alternar
        # (pyo3 recompila con cualquier cambio de PYO3_PYTHON, y la RUTA del
        # intérprete difiere sí o sí entre dev-shell y venv). Por eso el criterio
        # es no alternar: usa un flujo (la suite) y PyO3 se compila una vez.
        py = pkgs.python313.withPackages (ps: with ps; [
          pip
          setuptools
          wheel
        ]);

        # Expone SOLO python3.11 (no un python311 entero, que chocaría con
        # python313) para que hatch lo reutilice en sus envs (todos 3.11) en vez
        # de bajarse un CPython standalone cuyo LIBDIR rompe el linker con mold.
        python311bin = pkgs.runCommand "python311-bin" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.python311}/bin/python3.11 $out/bin/python3.11
        '';

        protobuf3 = pkgs.protobuf;
      in
      {
        devShells.default = pkgs.devshell.mkShell {
          name = "sail-dev";

          packages =
            (with pkgs; [
              fzf
              bashInteractive
              coreutils
              findutils
              gnugrep
              gnused
              gawk
              which
              procps
              ripgrep
              curl
              unzip

              nodejs_22
              pnpm
              zig
              maturin

              rustToolchain
              cargo-nextest
              pkg-config

              jdk17
              maven

              hatch
              uv

              mold
              sccache
            ])
            ++ [ py python311bin protobuf3 ]
            ++ lib.optionals isLinux [ pkgs.stdenv.cc.cc.lib pkgs.gcc ];

          env = [
            { name = "RUST_BACKTRACE"; value = "1"; }
            { name = "PROTOC"; value = "${protobuf3}/bin/protoc"; }
            { name = "PYO3_PYTHON"; value = "${py}/bin/python"; }
            { name = "PYTHON_SYS_EXECUTABLE"; value = "${py}/bin/python"; }
            { name = "PYO3_USE_ABI3"; value = "0"; }
            { name = "PATH"; prefix = "${protobuf3}/bin"; }
            { name = "PKG_CONFIG_PATH"; prefix = "${py}/lib/pkgconfig"; }
            { name = "PYTHONPATH"; eval = "$PRJ_ROOT/python"; }
          ];

          commands = [
            {
              category = "build";
              name = "sail-build";
              help = "Build and install pysail in the venv as editable (maturin develop)";
              command = ''hatch run maturin develop "$@"'';
            }
            {
              category = "build";
              name = "sail-nix-build";
              help = "Reproducible build of pysail via Nix sandbox — capped at SAIL_BUILD_JOBS=4 cores";
              command = ''
                cd "$PRJ_ROOT"
                jobs="''${SAIL_BUILD_JOBS:-4}"
                echo "Building with --cores $jobs --max-jobs 1 (override with SAIL_BUILD_JOBS=N)"
                nix build .#pysail --cores "$jobs" --max-jobs 1 "$@"
                echo ""
                echo "Output: $PRJ_ROOT/result"
              '';
            }
            {
              category = "build";
              name = "sail-fmt";
              help = "Format Rust code (nightly rustfmt)";
              command = ''cargo fmt "$@"'';
            }
            {
              category = "build";
              name = "sail-clippy";
              help = "Run clippy --all-targets --all-features -- -D warnings";
              command = ''cargo clippy --all-targets --all-features -- -D warnings "$@"'';
            }
            {
              category = "build";
              name = "sail-precommit";
              help = "Run the full pre-commit pipeline (fmt + clippy + build + nextest)";
              command = ''
                set -e
                cargo fmt
                cargo clippy --all-targets --all-features -- -D warnings
                cargo build
                env SAIL_UPDATE_GOLD_DATA=1 cargo nextest run
                cargo fmt
              '';
            }

            {
              category = "cli";
              name = "sail-cli";
              help = "Shell interactivo de PySpark (spark shell) con server embebido";
              command = ''cargo run -p sail-cli -- spark shell "$@"'';
            }

            # `sail-flake-update` (de la rama) desactivado aquí: haría
            # `nix flake update` sobre $PRJ_ROOT (tu checkout de sail), no sobre
            # sail-dev. Para actualizar sail-dev usa la startup fenix-update o
            # `nix flake update fenix --flake ~/nix-os/sail-dev`.

            {
              category = "server";
              name = "sail-server";
              help = "Run Sail Spark Connect server on :50051";
              command = ''env RUST_LOG="''${RUST_LOG:-sail=debug}" SAIL_EXECUTION__DEFAULT_PARALLELISM=''${SAIL_EXECUTION__DEFAULT_PARALLELISM:-4} cargo run -p sail-cli -- spark server --port 50051 "$@"'';
            }
            {
              category = "server";
              name = "sail-server-spark";
              help = "Test server de la suite Spark parcheada (última versión del checkout; SAIL_SPARK=3.5.7 para otra)";
              command = ''
                ver="''${SAIL_SPARK:-$(ls "$PRJ_ROOT"/scripts/spark-tests/spark-*.patch 2>/dev/null | sed 's|.*/spark-\(.*\)\.patch|\1|' | sort -V | tail -1)}"
                env="test-spark.spark-$ver"
                _venv="$PRJ_ROOT/.venvs/$env"
                for _py in "$_venv/bin/python3" "$_venv/bin/python"; do
                  if [ -L "$_py" ] && [ ! -e "$_py" ]; then
                    echo "⛵ venv roto (symlink de Python colgado tras GC), lo recreo…"
                    rm -rf "$_venv"; break
                  fi
                done
                sail-fetch-pyspark "$ver"
                hatch run "$env:python" -c 'import pyspark' 2>/dev/null || hatch run "$env:install-pyspark"
                hatch run "$env:bash" scripts/spark-tests/run-server.sh
              '';
            }
            {
              category = "server";
              name = "sail-server-ibis";
              help = "Run the test server for the Ibis suite (catalog + UDF env)";
              command = ''
                _venv="$PRJ_ROOT/.venvs/test-ibis"
                for _py in "$_venv/bin/python3" "$_venv/bin/python"; do
                  if [ -L "$_py" ] && [ ! -e "$_py" ]; then
                    echo "⛵ venv roto (symlink de Python colgado tras GC), lo recreo…"
                    rm -rf "$_venv"; break
                  fi
                done
                hatch run test-ibis:bash scripts/spark-tests/run-server.sh
              '';
            }

            {
              category = "test";
              name = "sail-test";
              help = "Run all Rust tests (nextest)";
              command = ''cargo nextest run "$@"'';
            }
            {
              category = "test";
              name = "sail-test-feature";
              help = "Run pytest BDD feature tests against Sail server on :50051";
              command = ''export SPARK_REMOTE="''${SPARK_REMOTE:-sc://localhost:50051}" && hatch run pytest python/pysail/tests/spark/function/test_features.py "$@"'';
            }
            {
              category = "test";
              name = "sail-test-ibis";
              help = "Run Ibis tests against Sail server on :50051 (auto-clones ibis-testing-data)";
              command = ''
                _data_dir="$PRJ_ROOT/opt/ibis-testing-data"
                if [ ! -d "$_data_dir/.git" ]; then
                  echo "⛵ Cloning ibis-testing-data (shallow)..."
                  git clone --depth 1 https://github.com/ibis-project/testing-data.git "$_data_dir"
                fi
                _venv="$PRJ_ROOT/.venvs/test-ibis"
                for _py in "$_venv/bin/python3" "$_venv/bin/python"; do
                  if [ -L "$_py" ] && [ ! -e "$_py" ]; then
                    echo "⛵ venv roto (symlink de Python colgado tras GC), lo recreo…"
                    rm -rf "$_venv"; break
                  fi
                done
                export SPARK_REMOTE="sc://localhost:50051"
                hatch run test-ibis:bash scripts/spark-tests/run-tests.sh "$@"
              '';
            }
            {
              category = "test";
              name = "sail-test-jvm";
              help = "Run feature tests against local Spark JVM (no Sail)";
              command = ''SPARK_REMOTE="local" hatch run pytest python/pysail/tests/spark/function/test_features.py -v "$@"'';
            }
            {
              category = "test";
              name = "sail-fetch-pyspark";
              help = "Descarga PySpark parcheado del ÚLTIMO run de artifacts (sin compilar). Args: versiones; por defecto la última del checkout";
              command = ''
                set -euo pipefail
                repo="''${SAIL_REPO:-lakehq/sail}"
                dist="$PRJ_ROOT/opt/spark/python/dist"
                if [ "$#" -gt 0 ]; then
                  vers=("$@")
                else
                  vers=("$(ls "$PRJ_ROOT"/scripts/spark-tests/spark-*.patch 2>/dev/null | sed 's|.*/spark-\(.*\)\.patch|\1|' | sort -V | tail -1)")
                fi
                missing=()
                for v in "''${vers[@]}"; do [ -f "$dist/pyspark-$v.tar.gz" ] || missing+=("$v"); done
                if [ "''${#missing[@]}" -eq 0 ]; then
                  echo "⛵ PySpark ya presente: ''${vers[*]}"; exit 0
                fi
                echo "⛵ Buscando el último run exitoso de spark-package-artifacts…"
                run_id="$(curl -s "https://api.github.com/repos/$repo/actions/workflows/spark-package-artifacts.yml/runs?status=success&per_page=1" | grep -oE '"id": *[0-9]+' | head -1 | grep -oE '[0-9]+')"
                if [ -z "$run_id" ]; then
                  echo "No pude obtener el run_id (¿sin red o rate-limit de la API?)." >&2; exit 1
                fi
                echo "  run_id=$run_id"
                mkdir -p "$dist"
                tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
                for v in "''${missing[@]}"; do
                  url="https://nightly.link/$repo/actions/runs/$run_id/pyspark-$v.zip"
                  echo "⛵ Bajando pyspark-$v…"
                  if ! curl -fSL --retry 3 -o "$tmp/pyspark-$v.zip" "$url"; then
                    echo "Fallo al bajar $url" >&2
                    echo "Puede que esa versión no esté en el último run; míralo o compila en local con scripts/spark-tests/build-pyspark.sh." >&2
                    exit 1
                  fi
                  unzip -o -j "$tmp/pyspark-$v.zip" "pyspark-$v.tar.gz" -d "$dist"
                done
                echo "⛵ Listo:"; ls -1 "$dist"/pyspark-*.tar.gz
              '';
            }
            {
              category = "test";
              name = "sail-test-spark";
              help = "Tests Spark parcheados (última versión del checkout; SAIL_SPARK=3.5.7 para otra). Auto-fetch de PySpark";
              command = ''
                ver="''${SAIL_SPARK:-$(ls "$PRJ_ROOT"/scripts/spark-tests/spark-*.patch 2>/dev/null | sed 's|.*/spark-\(.*\)\.patch|\1|' | sort -V | tail -1)}"
                env="test-spark.spark-$ver"
                _venv="$PRJ_ROOT/.venvs/$env"
                for _py in "$_venv/bin/python3" "$_venv/bin/python"; do
                  if [ -L "$_py" ] && [ ! -e "$_py" ]; then
                    echo "⛵ venv roto (symlink de Python colgado tras GC), lo recreo…"
                    rm -rf "$_venv"; break
                  fi
                done
                sail-fetch-pyspark "$ver"
                hatch run "$env:python" -c 'import pyspark' 2>/dev/null || hatch run "$env:install-pyspark"
                hatch run "$env:bash" scripts/spark-tests/run-tests.sh "$@"
              '';
            }
            {
              category = "test";
              name = "sail-pytest";
              help = "Run pytest against Sail server (set SPARK_REMOTE for you)";
              command = ''export SPARK_REMOTE="sc://localhost:50051" && hatch run pytest "$@"'';
            }
          ];

          # Mantiene rustc/fenix al día: 1×/día actualiza el lock de ESTE flake
          # (~/nix-os/sail-dev). Toca sail-dev/flake.lock (trackeado) → lo verás
          # modificado en git; commitéalo cuando quieras. Stamp diario para no
          # correr en cada `cd`.
          devshell.startup.fenix-update.text = ''
            _flake_dir="$HOME/nix-os/sail-dev"
            _stamp_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/sail-dev"
            _stamp_file="$_stamp_dir/fenix-update"
            _today=$(date +%Y-%m-%d)
            _last_attempt=$(cat "$_stamp_file" 2>/dev/null || true)
            if [ -f "$_flake_dir/flake.nix" ] && [ "$_last_attempt" != "$_today" ]; then
              mkdir -p "$_stamp_dir"
              _lock_before=$(shasum "$_flake_dir/flake.lock" 2>/dev/null | cut -d' ' -f1)
              echo -e "\033[1;33m⛵ Comprobando actualización del toolchain fenix (rustc…)…\033[0m"
              if (cd "$_flake_dir" && nix flake update fenix 2>&1); then
                echo "$_today" > "$_stamp_file"
                _lock_after=$(shasum "$_flake_dir/flake.lock" 2>/dev/null | cut -d' ' -f1)
                if [ "$_lock_before" != "$_lock_after" ]; then
                  echo -e "\033[1;32m✓ fenix actualizado. Recarga el entorno para el rustc nuevo:\033[0m"
                  echo -e "\033[1;36m  direnv reload   (o: exit && nix develop ~/nix-os/sail-dev)\033[0m"
                fi
              else
                echo -e "\033[1;31m⚠ No se pudo actualizar fenix (¿sin red?). Sigo con el toolchain actual.\033[0m"
              fi
            fi
          '';

          devshell.startup.sail-shell.text = ''
            unset PYTHONHOME

            # Deja 2 cores libres al compilar/testear (con todos los cores + RAM
            # al tope el escritorio se congela). Adaptativo. A tope si estás AFK:
            #   CARGO_BUILD_JOBS=$(nproc) cargo build
            # Comodidad local; no lo lleves al PR.
            _ncpu=$(nproc 2>/dev/null || echo 4)
            _jobs=$(( _ncpu > 2 ? _ncpu - 2 : 1 ))
            export CARGO_BUILD_JOBS="$_jobs"
            export NEXTEST_TEST_THREADS="$_jobs"

            # JAVA_HOME tras el rc del usuario para que no lo pise SDKMAN et al.
            export JAVA_HOME="${pkgs.jdk17.home}"
            export PATH="$JAVA_HOME/bin:$PATH"

            cargo() {
              if [[ "''${1:-}" == +* ]]; then
                shift
              fi
              command cargo "$@"
            }
            export -f cargo

            if [ -z "''${_NIX_OLD_PS1:-}" ]; then
              export _NIX_OLD_PS1="$PS1"
            fi
            export PS1="\[\e[48;5;24m\]\[\e[38;5;231m\]  ⛵ sail  \[\e[0m\] \[\e[38;5;75m\]\w\[\e[0m\] \$ "

            if [ -e "${pkgs.fzf}/share/fzf/key-bindings.bash" ]; then
              source "${pkgs.fzf}/share/fzf/key-bindings.bash"
            fi
            if [ -e "${pkgs.fzf}/share/fzf/completion.bash" ]; then
              source "${pkgs.fzf}/share/fzf/completion.bash"
            fi
          '' + lib.optionalString isLinux ''
            export LD_LIBRARY_PATH=${py}/lib:${pkgs.python311}/lib:${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
            export RUSTFLAGS="-C link-arg=-fuse-ld=mold -C link-arg=-L${pkgs.python311}/lib"
            export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
          '';
        };
      }
    );
}
