import sys
import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from datetime import datetime

args = getResolvedOptions(sys.argv, [
    'JOB_NAME'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("=" * 60)
print("📊 ETL DE VENTAS ")
print("=" * 60)

# ============================================
# CONFIGURACIÓN JDBC
# ============================================
jdbc_url = "jdbc:mysql://erpnext-dev-ha-single-region-erpnextdb-mizgjhv6ygda.calu0eqgkv6d.us-east-1.rds.amazonaws.com:3306/erpnext"

jdbc_properties = {
    "user": "admin",
    "password": "erpnextDBPass123!",
    "driver": "com.mysql.cj.jdbc.Driver",
    "useSSL": "false",
    "connectTimeout": "60000",
    "socketTimeout": "60000"
}

# ============================================
# 1. LEER FACTURAS
# ============================================
print("📥 Leyendo facturas de venta...")

sales_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabSales Invoice`",
    properties=jdbc_properties
)

print(f"📊 Facturas leídas: {sales_df.count()}")

# ============================================
# 2. LEER CLIENTES
# ============================================
print("📥 Leyendo clientes...")

customers_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabCustomer`",
    properties=jdbc_properties
)

print(f"📊 Clientes leídos: {customers_df.count()}")

# ============================================
# 3. TRANSFORMACIONES
# ============================================
print("🧹 Limpiando datos...")

cleaned_df = sales_df \
    .filter(col("docstatus") == 1) \
    .filter(col("grand_total").isNotNull()) \
    .withColumn("total_amount", col("grand_total").cast("double")) \
    .withColumn("net_amount",
                when(col("rounded_total").isNotNull(), col("rounded_total").cast("double"))
                .otherwise(col("grand_total").cast("double"))) \
    .withColumn("tax_amount",
                when(col("total_taxes_and_charges").isNotNull(),
                     col("total_taxes_and_charges").cast("double"))
                .otherwise(0.0)) \
    .withColumn("fiscal_year", year(col("posting_date"))) \
    .withColumn("fiscal_month", month(col("posting_date"))) \
    .withColumn("quarter", quarter(col("posting_date"))) \
    .withColumn("processed_date", lit(datetime.now().date())) \
    .dropDuplicates(["name"])

print(f"📊 Registros después de limpieza: {cleaned_df.count()}")

# ============================================
# 4. ENRIQUECIMIENTO CON CLIENTES (SIN DUPLICADOS)
# ============================================
print("👤 Enriqueciendo con clientes...")

# Renombrar columnas de clientes para evitar duplicados
customers_select = customers_df.select(
    col("name").alias("customer_id"),
    col("customer_name").alias("customer_name_clean"),
    col("customer_type").alias("customer_type_clean"),
    col("territory").alias("territory_clean"),
    col("customer_group").alias("customer_group_clean")
)

# Hacer el join
sales_with_customers = cleaned_df.join(
    customers_select,
    cleaned_df.customer == customers_select.customer_id,
    "left"
)

print(f"📊 Registros enriquecidos: {sales_with_customers.count()}")

# Verificar columnas para debug
print(f"Columnas finales: {sales_with_customers.columns}")

# ============================================
# 5. GUARDAR EN S3
# ============================================
print("💾 Guardando en S3...")

account_id = boto3.client('sts').get_caller_identity().get('Account')
processed_bucket = f"erp-processed-data-{account_id}-us-east-1"
processed_path = f"s3://{processed_bucket}/sales/"

sales_with_customers.write \
    .mode("overwrite") \
    .partitionBy("fiscal_year", "quarter") \
    .option("compression", "snappy") \
    .parquet(processed_path)

print(f"✅ Datos guardados en: {processed_path}")
print(f"📊 Registros procesados: {sales_with_customers.count()}")
print("✅ ETL completado")

job.commit()
