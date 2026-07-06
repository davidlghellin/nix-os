from src.queries import query


def test_select_1(conn):
    assert query(conn, "SELECT 1 AS ok").to_pydict()["ok"] == [1]


def test_arithmetic(conn):
    assert query(conn, "SELECT 2 + 3 AS s").to_pydict()["s"] == [5]
