"""Prueba rápida: conecta al server Spark Connect remoto y hace SELECT 1."""

import os

from pyspark.sql import SparkSession


def main():
    url = os.environ.get("SPARK_REMOTE", "sc://korriban:50051")
    spark = SparkSession.builder.remote(url).getOrCreate()
    print(f"✅ Conectado a {url}")
    spark.sql("SELECT 1 AS ok").show()
    spark.stop()


if __name__ == "__main__":
    main()
