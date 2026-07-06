import os

import pytest

from src.queries import connect


def _uri():
    return os.environ.get("FLIGHT_SQL_URI", "grpc://korriban:32010")


def pytest_report_header():
    return f"flight sql uri: {_uri()}"


@pytest.fixture(scope="session")
def conn():
    """Conexión ADBC Flight SQL contra el server remoto (FLIGHT_SQL_URI)."""
    c = connect(_uri())
    yield c
    c.close()
