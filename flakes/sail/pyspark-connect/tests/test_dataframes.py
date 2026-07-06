from src.dataframes import suma_columnas


def test_suma_columnas(spark):
    df = spark.createDataFrame([(1, 2), (3, 4)], ["a", "b"])
    rows = suma_columnas(df, "a", "b", "suma").collect()
    assert rows[0]["suma"] == 3
    assert rows[1]["suma"] == 7


def test_select_1(spark):
    assert spark.sql("SELECT 1 AS ok").collect()[0]["ok"] == 1
