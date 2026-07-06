"""Prueba rápida: conecta por Flight SQL y hace SELECT 1."""

import os

from src.queries import connect, query


def main():
    uri = os.environ.get("FLIGHT_SQL_URI", "grpc://korriban:32010")
    conn = connect(uri)
    print(f"✅ Conectado a {uri}")
    print(query(conn, "SELECT 1 AS ok").to_pydict())
    conn.close()


if __name__ == "__main__":
    main()
