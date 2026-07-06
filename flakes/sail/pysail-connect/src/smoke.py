"""Prueba rápida: reusa el server externo si está, si no arranca pysail embebido."""

from src.session import _external, get_session


def main():
    spark, server, mode = get_session()
    if mode == "external":
        host, port = _external()
        print(f"✅ Reusando server externo en sc://{host}:{port}")
    else:
        ip, port = server.listening_address
        print(f"✅ Server pysail EMBEBIDO en sc://{ip}:{port} (no había externo)")
    spark.sql("SELECT 1 AS ok").show()
    spark.stop()
    if server is not None:
        server.stop()


if __name__ == "__main__":
    main()
