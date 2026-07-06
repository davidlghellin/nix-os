"""Sesión Sail con auto-detección:

- Si hay un server Spark Connect ya escuchando (p.ej. el systemd de korriban en
  50051) → se REUSA.
- Si no hay ninguno → se arranca uno EMBEBIDO con pysail (sin server externo).

Config por entorno: SAIL_HOST (def. localhost), SAIL_PORT (def. 50051).
"""

import os
import socket

from pyspark.sql import SparkSession


def _external():
    return os.environ.get("SAIL_HOST", "localhost"), int(os.environ.get("SAIL_PORT", "50051"))


def _is_open(host: str, port: int, timeout: float = 1.0) -> bool:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            s.connect((host, port))
            return True
    except OSError:
        return False


def get_session():
    """Devuelve (spark, server, mode).

    - mode == "external": se reusó un server ya corriendo; server is None.
    - mode == "embedded": se arrancó uno con pysail; hay que server.stop() al final.
    """
    host, port = _external()
    if _is_open(host, port):
        spark = SparkSession.builder.remote(f"sc://{host}:{port}").getOrCreate()
        return spark, None, "external"

    from pysail.spark import SparkConnectServer

    server = SparkConnectServer("127.0.0.1", 0)  # localhost, puerto aleatorio
    server.start(background=True)
    ip, eport = server.listening_address
    spark = SparkSession.builder.remote(f"sc://{ip}:{eport}").getOrCreate()
    return spark, server, "embedded"
