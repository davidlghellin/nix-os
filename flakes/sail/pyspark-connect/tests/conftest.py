import os

import pytest
from pyspark.sql import SparkSession


def _remote():
    return os.environ.get("SPARK_REMOTE", "sc://korriban:50051")


def pytest_report_header():
    return f"spark connect remote: {_remote()}"


@pytest.fixture(scope="session")
def spark():
    """Sesión Spark contra el server Connect remoto (SPARK_REMOTE)."""
    s = SparkSession.builder.remote(_remote()).getOrCreate()
    yield s
    s.stop()
