import pytest

from src.session import get_session


@pytest.fixture(scope="session")
def spark():
    """Sesión Spark: reusa un server externo si escucha, si no pysail embebido."""
    spark, server, mode = get_session()
    print(f"\n[sail] backend: {mode}")
    yield spark
    spark.stop()
    if server is not None:
        server.stop()
