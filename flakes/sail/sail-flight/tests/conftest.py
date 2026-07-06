import os
import socket
from urllib.parse import urlparse

import pytest

from src.queries import connect


def _uri():
    return os.environ.get("FLIGHT_SQL_URI", "grpc://korriban:32010")


def _reachable(uri: str, timeout: float = 2.0) -> bool:
    u = urlparse(uri)  # grpc://host:port
    if not u.hostname:
        return False
    try:
        with socket.create_connection((u.hostname, u.port or 32010), timeout):
            return True
    except (OSError, ValueError):
        return False


def pytest_report_header():
    return f"flight sql uri: {_uri()}"


@pytest.fixture(scope="session")
def conn():
    """Conexión ADBC Flight SQL contra el server remoto (FLIGHT_SQL_URI).

    Si el server no está accesible, se SALTA la suite (en vez de romper).
    """
    uri = _uri()
    if not _reachable(uri):
        pytest.skip(f"Flight SQL no accesible en {uri} (¿server levantado?)")
    c = connect(uri)
    yield c
    c.close()
