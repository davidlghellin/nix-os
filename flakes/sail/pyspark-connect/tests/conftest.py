import os
import socket
from urllib.parse import urlparse

import pytest
from pyspark.sql import SparkSession


def _remote():
    return os.environ.get("SPARK_REMOTE", "sc://korriban:50051")


def _reachable(remote: str, timeout: float = 2.0) -> bool:
    u = urlparse(remote)  # sc://host:port
    if not u.hostname:
        return False
    try:
        with socket.create_connection((u.hostname, u.port or 50051), timeout):
            return True
    except (OSError, ValueError):
        return False


def pytest_report_header():
    return f"spark connect remote: {_remote()}"


@pytest.fixture(scope="session")
def spark():
    """Sesión Spark contra el server Connect remoto (SPARK_REMOTE).

    Si el server no está accesible, se SALTA la suite (en vez de romper).
    """
    remote = _remote()
    if not _reachable(remote):
        pytest.skip(f"Spark Connect no accesible en {remote} (¿server levantado?)")
    s = SparkSession.builder.remote(remote).getOrCreate()
    yield s
    s.stop()
