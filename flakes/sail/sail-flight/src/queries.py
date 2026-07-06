"""Cliente Arrow Flight SQL mínimo vía ADBC (sin pyspark)."""

from adbc_driver_flightsql import dbapi


def connect(uri: str):
    """Abre una conexión ADBC contra un server Flight SQL (grpc://host:port).

    autocommit=True: Sail Flight SQL no maneja transacciones; así evitamos el
    warning "Cannot disable autocommit".
    """
    return dbapi.connect(uri, autocommit=True)


def query(conn, sql: str):
    """Ejecuta SQL y devuelve el resultado como pyarrow.Table."""
    cur = conn.cursor()
    try:
        cur.execute(sql)
        return cur.fetch_arrow_table()
    finally:
        cur.close()
