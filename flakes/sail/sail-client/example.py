#!/usr/bin/env python3
import argparse
import os
import sys

def main():
    try:
        from pyspark.sql import SparkSession
    except Exception as e:
        print("ERROR: PySpark no está instalado en este entorno. Ejecuta 'pip install pyspark'.")
        raise

    parser = argparse.ArgumentParser(description="Cliente simple de Spark Connect")
    parser.add_argument(
        "--url",
        default=os.environ.get("SPARK_CONNECT_URL", "sc://localhost:15002"),
        help="URL del servidor Spark Connect (ej. sc://host:15002). "
             "También se puede definir con la variable de entorno SPARK_CONNECT_URL."
    )
    parser.add_argument(
        "--sql",
        default="SELECT 1 AS ok",
        help="Consulta SQL a ejecutar."
    )
    parser.add_argument(
        "--to-pandas",
        action="store_true",
        help="Convertir el resultado a pandas y mostrarlo."
    )
    parser.add_argument(
        "--show",
        type=int,
        default=20,
        help="Usar DataFrame.show(n) en lugar de pandas (por defecto 20)."
    )

    args = parser.parse_args()

    print(f"🔗 Conectando a Spark Connect en {args.url} …")
    spark = SparkSession.builder.remote(args.url).getOrCreate()

    try:
        print(f"▶️  SQL: {args.sql}")
        df = spark.sql(args.sql)

        if args.to_pandas:
            pdf = df.toPandas()
            print(pdf)
        else:
            df.show(args.show, truncate=False)
    finally:
        print("⏹️  Parando sesión Spark…")
        spark.stop()

if __name__ == "__main__":
    sys.exit(main())

