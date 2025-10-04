{
  description = "Entorno de desarrollo Python reproducible con Nix flakes";

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
        python311Packages.virtualenv
        python311Packages.pip
        python311Packages.wheel
      ];

      # Variables de entorno útiles
      shellHook = ''
        export PS1="\[\033[1;32m\]\u@\h \[\033[1;34m\]\w \[\033[0;33m\]$ \[\033[0m\] "

        echo "🐍 Entorno Python listo!"
        echo "Python: $(python3 --version)"
        echo "Pip: $(pip --version)"
        echo "Puedes instalar deps locales: pip install -r requirements.txt"

        VENV_DIR="''\${VENV_DIR:-.venv}"
        if [ ! -d "''${VENV_DIR}" ]; then
          echo "🔧 Creando entorno virtual en ''${VENV_DIR} (Python 3.11)…"
          python3 -m venv "''${VENV_DIR}"
        fi
        # shellcheck disable=SC1090
        . "''${VENV_DIR}/bin/activate"
        python -m pip install --upgrade --disable-pip-version-check pip setuptools wheel

        pip install \
          "pyspark>=3.5,<4.1" \
          "pysail[spark]==0.3.2" \
          "pandas>=2.0,<3.0" \
          "pyarrow>=11.0.0,<16.0.0" \
          "grpcio>=1.62.0" \
          grpcio-tools \
          ptpython

	alias launch-sail-server='sail spark server --ip 0.0.0.0 --port 50051'
	alias debug-sail-server='RUST_LOG=debug sail spark server --ip 0.0.0.0 --port 50051'

      '';
    };
  };
}

