import sys
import boto3
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime

# ============================================
# CONFIGURACIÓN
# ============================================
args = getResolvedOptions(sys.argv, [
    'JOB_NAME'
    # , 'db_name',
    # 'redshift_url',
    # 'redshift_user',
    # 'redshift_password'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("=" * 60)
print("📊 ETL DE VENTAS - ANÁLISIS DE MUEBLES")
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
# 1. LEER DATOS DE RDS
# ============================================
print("\n📥 Leyendo datos de RDS...")

# 1.1 Facturas de venta
sales_invoices_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabSales Invoice`",
    properties=jdbc_properties
)
print(f"📊 Facturas de venta: {sales_invoices_df.count()}")

# 1.2 Líneas de factura
invoice_items_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabSales Invoice Item`",
    properties=jdbc_properties
)
print(f"📊 Líneas de factura: {invoice_items_df.count()}")

# 1.3 Clientes
customers_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabCustomer`",
    properties=jdbc_properties
)
print(f"📊 Clientes: {customers_df.count()}")

# 1.4 Productos
products_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabItem`",
    properties=jdbc_properties
)
print(f"📊 Productos: {products_df.count()}")

# 1.5 Pedidos de venta (para contexto)
sales_orders_df = spark.read.jdbc(
    url=jdbc_url,
    table="`tabSales Order`",
    properties=jdbc_properties
)
print(f"📊 Pedidos de venta: {sales_orders_df.count()}")

# ============================================
# 2. LIMPIEZA DE FACTURAS
# ============================================
print("\n🧹 Limpiando datos...")

# Filtrar solo facturas completadas
valid_invoices = sales_invoices_df \
    .filter(col("docstatus") == 1) \
    .filter(col("grand_total").isNotNull()) \
    .filter(col("grand_total") > 0)

print(f"📊 Facturas válidas: {valid_invoices.count()}")

# ============================================
# 3. UNIR FACTURAS CON LÍNEAS Y PRODUCTOS
# ============================================
print("\n🔗 Uniendo datos...")

# 3.1 Unir líneas con facturas
invoices_with_items = invoice_items_df.join(
    valid_invoices.select(
        col("name").alias("invoice_name"),
        col("customer"),
        col("posting_date"),
        col("due_date"),
        col("grand_total"),
        col("rounded_total"),
        col("total_taxes_and_charges"),
        col("status"),
        col("territory"),
        col("customer_group")
    ),
    invoice_items_df.parent == col("invoice_name"),
    "inner"
)

print(f"📊 Facturas con líneas: {invoices_with_items.count()}")

# 3.2 Unir con productos
invoices_with_products = invoices_with_items.join(
    products_df.select(
        col("name").alias("product_id"),
        col("item_code").alias("item_code_product"),
        col("item_name").alias("product_name"),
        col("item_group").alias("item_group_product"),
        col("standard_rate").alias("standard_rate_product"),
        col("valuation_rate").alias("valuation_rate_product"),
        col("is_stock_item").alias("is_stock_item_product")
    ),
    invoices_with_items.item_code == col("item_code_product"),
    "left"
)

print(f"📊 Facturas con productos: {invoices_with_products.count()}")

# ============================================
# 4. ENRIQUECIMIENTO CON CLIENTES
# ============================================
print("\n👤 Enriquociendo con clientes...")

final_df = invoices_with_products.join(
    customers_df.select(
        col("name").alias("customer_id"),
        col("customer_name"),
        col("customer_type"),
        col("territory").alias("customer_territory"),
        col("customer_group").alias("customer_group_name"),
        col("industry"),
        col("market_segment")
    ),
    invoices_with_products.customer == col("customer_id"),
    "left"
)

print(f"📊 Datos enriquecidos: {final_df.count()}")

# ============================================
# 5. TRANSFORMACIONES Y CÁLCULOS
# ============================================
print("\n📊 Calculando métricas...")

sales_analytics_df = final_df \
    .withColumn("invoice_date", to_date(col("posting_date"))) \
    .withColumn("fiscal_year", year(col("invoice_date"))) \
    .withColumn("fiscal_month", month(col("invoice_date"))) \
    .withColumn("quarter", quarter(col("invoice_date"))) \
    .withColumn("week_number", weekofyear(col("invoice_date"))) \
    .withColumn("invoice_year_month", date_format(col("invoice_date"), "yyyy-MM")) \
    .withColumn("total_line_amount", 
                when(col("amount").isNotNull(), col("amount").cast("double"))
                .otherwise(col("qty") * col("rate"))) \
    .withColumn("unit_cost", 
                when(col("valuation_rate_product").isNotNull() & (col("valuation_rate_product") > 0), 
                     col("valuation_rate_product").cast("double"))
                .otherwise(col("rate") * 0.6)) \
    .withColumn("line_cost", col("qty") * col("unit_cost")) \
    .withColumn("line_margin", col("total_line_amount") - col("line_cost")) \
    .withColumn("margin_percentage", 
                when(col("total_line_amount") > 0, 
                     (col("line_margin") / col("total_line_amount")) * 100)
                .otherwise(0)) \
    .withColumn("discount_amount_abs", 
                when(col("discount_amount").isNotNull(), col("discount_amount").cast("double"))
                .otherwise(0)) \
    .withColumn("discount_percentage_abs", 
                when(col("discount_percentage").isNotNull(), col("discount_percentage").cast("double"))
                .otherwise(0)) \
    .withColumn("tax_rate", 
                when(col("item_tax_rate").isNotNull(), 
                     regexp_extract(col("item_tax_rate"), r'"rate":([0-9.]+)', 1).cast("double"))
                .otherwise(18.0)) \
    .withColumn("tax_amount_line", 
                (col("total_line_amount") - col("discount_amount_abs")) * (col("tax_rate") / 100)) \
    .withColumn("is_completed", lit(1)) \
    .withColumn("processed_date", lit(datetime.now().date()))

# ============================================
# 6. AGRUPACIONES Y KPIs
# ============================================
print("\n📈 Calculando KPIs...")

# 6.1 Resumen por factura
invoice_summary = sales_analytics_df.groupBy(
    "invoice_name",
    "customer_name",
    "invoice_date",
    "fiscal_year",
    "quarter",
    "fiscal_month",
    "grand_total",
    "status",
    "customer_territory",
    "customer_group_name"
).agg(
    count("item_code").alias("total_items"),
    sum("qty").alias("total_quantity"),
    sum("total_line_amount").alias("invoice_subtotal"),
    sum("line_cost").alias("invoice_cost"),
    sum("line_margin").alias("invoice_margin"),
    avg("margin_percentage").alias("avg_margin_percentage"),
    sum("tax_amount_line").alias("invoice_tax_total")
).withColumn("margin_amount", col("invoice_margin")) \
 .withColumn("margin_percentage", (col("invoice_margin") / col("invoice_subtotal")) * 100)

# 6.2 Resumen por producto
product_summary = sales_analytics_df.groupBy(
    "item_code",
    "product_name",
    "item_group"
).agg(
    count("parent").alias("times_sold"),
    sum("qty").alias("total_quantity_sold"),
    sum("total_line_amount").alias("total_revenue"),
    sum("line_cost").alias("total_cost"),
    sum("line_margin").alias("total_margin"),
    avg("margin_percentage").alias("avg_margin_percentage")
).withColumn("margin_percentage", (col("total_margin") / col("total_revenue")) * 100)

# 6.3 Resumen por cliente
customer_summary = sales_analytics_df.groupBy(
    "customer_name",
    "customer_type",
    "customer_territory",
    "customer_group_name",
    "industry",
    "market_segment"
).agg(
    countDistinct("invoice_name").alias("total_invoices"),
    sum("qty").alias("total_quantity_purchased"),
    sum("total_line_amount").alias("total_spent"),
    sum("line_margin").alias("total_profit_generated"),
    avg("margin_percentage").alias("avg_margin_percentage")
).withColumn("margin_percentage", (col("total_profit_generated") / col("total_spent")) * 100)

# 6.4 Ventas por mes
monthly_sales = sales_analytics_df.groupBy(
    "fiscal_year",
    "fiscal_month",
    "invoice_year_month"
).agg(
    countDistinct("invoice_name").alias("total_invoices"),
    sum("total_line_amount").alias("monthly_revenue"),
    sum("line_margin").alias("monthly_profit")
).orderBy("fiscal_year", "fiscal_month")

# ============================================
# 7. GUARDAR EN S3
# ============================================
print("\n💾 Guardando en S3...")

account_id = boto3.client('sts').get_caller_identity().get('Account')
processed_bucket = f"erp-processed-data-{account_id}-us-east-1"

# 7.1 Tabla de hechos - Detalle de ventas
fact_sales_path = f"s3://{processed_bucket}/fact_sales/"
sales_analytics_df.write \
    .mode("overwrite") \
    .partitionBy("fiscal_year", "quarter") \
    .option("compression", "snappy") \
    .parquet(fact_sales_path)
print(f"✅ Fact Sales guardado en: {fact_sales_path}")

# 7.2 Resumen por factura
invoice_summary_path = f"s3://{processed_bucket}/dim_invoice/"
invoice_summary.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .parquet(invoice_summary_path)
print(f"✅ Dim Invoice guardado en: {invoice_summary_path}")

# 7.3 Resumen por producto
product_summary_path = f"s3://{processed_bucket}/dim_product/"
product_summary.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .parquet(product_summary_path)
print(f"✅ Dim Product guardado en: {product_summary_path}")

# 7.4 Resumen por cliente
customer_summary_path = f"s3://{processed_bucket}/dim_customer/"
customer_summary.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .parquet(customer_summary_path)
print(f"✅ Dim Customer guardado en: {customer_summary_path}")

# 7.5 Ventas mensuales
monthly_sales_path = f"s3://{processed_bucket}/kpi_monthly_sales/"
monthly_sales.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .parquet(monthly_sales_path)
print(f"✅ KPI Monthly Sales guardado en: {monthly_sales_path}")

# ============================================
# 8. ESCRIBIR EN REDSHIFT
# ============================================
# print("\n📤 Cargando a Redshift...")

# if sales_analytics_df.count() > 0:
#     try:
#         # 8.1 Fact Sales
#         sales_analytics_df.write \
#             .format("jdbc") \
#             .option("driver", "com.amazon.redshift.jdbc42.Driver") \
#             .option("url", args['redshift_url']) \
#             .option("dbtable", "fact_sales") \
#             .option("user", args['redshift_user']) \
#             .option("password", args['redshift_password']) \
#             .option("tempdir", f"s3://{processed_bucket}/temp/") \
#             .mode("append") \
#             .save()
#         print("✅ Fact Sales cargado a Redshift")
        
#         # 8.2 Dim Invoice
#         invoice_summary.write \
#             .format("jdbc") \
#             .option("driver", "com.amazon.redshift.jdbc42.Driver") \
#             .option("url", args['redshift_url']) \
#             .option("dbtable", "dim_invoice") \
#             .option("user", args['redshift_user']) \
#             .option("password", args['redshift_password']) \
#             .option("tempdir", f"s3://{processed_bucket}/temp/") \
#             .mode("append") \
#             .save()
#         print("✅ Dim Invoice cargado a Redshift")
        
#         # 8.3 Dim Product
#         product_summary.write \
#             .format("jdbc") \
#             .option("driver", "com.amazon.redshift.jdbc42.Driver") \
#             .option("url", args['redshift_url']) \
#             .option("dbtable", "dim_product") \
#             .option("user", args['redshift_user']) \
#             .option("password", args['redshift_password']) \
#             .option("tempdir", f"s3://{processed_bucket}/temp/") \
#             .mode("append") \
#             .save()
#         print("✅ Dim Product cargado a Redshift")
        
#         # 8.4 Dim Customer
#         customer_summary.write \
#             .format("jdbc") \
#             .option("driver", "com.amazon.redshift.jdbc42.Driver") \
#             .option("url", args['redshift_url']) \
#             .option("dbtable", "dim_customer") \
#             .option("user", args['redshift_user']) \
#             .option("password", args['redshift_password']) \
#             .option("tempdir", f"s3://{processed_bucket}/temp/") \
#             .mode("append") \
#             .save()
#         print("✅ Dim Customer cargado a Redshift")
        
#         # 8.5 KPI Monthly Sales
#         monthly_sales.write \
#             .format("jdbc") \
#             .option("driver", "com.amazon.redshift.jdbc42.Driver") \
#             .option("url", args['redshift_url']) \
#             .option("dbtable", "kpi_monthly_sales") \
#             .option("user", args['redshift_user']) \
#             .option("password", args['redshift_password']) \
#             .option("tempdir", f"s3://{processed_bucket}/temp/") \
#             .mode("append") \
#             .save()
#         print("✅ KPI Monthly Sales cargado a Redshift")
        
#     except Exception as e:
#         print(f"⚠️ Error cargando a Redshift: {e}")
# else:
#     print("⚠️ No hay datos para cargar a Redshift")

# ============================================
# 9. REPORTE FINAL
# ============================================
print("\n" + "=" * 60)
print("📊 REPORTE FINAL DEL ETL")
print("=" * 60)
print(f"📊 Total de facturas procesadas: {invoice_summary.count()}")
print(f"📊 Total de productos vendidos: {product_summary.count()}")
print(f"📊 Total de clientes: {customer_summary.count()}")
print(f"📊 Meses procesados: {monthly_sales.count()}")

if monthly_sales.count() > 0:
    total_revenue = monthly_sales.select(sum("monthly_revenue")).collect()[0][0]
    total_profit = monthly_sales.select(sum("monthly_profit")).collect()[0][0]
    print(f"💰 Ingresos totales: {total_revenue:,.2f}" if total_revenue else "💰 Ingresos totales: 0")
    print(f"💰 Utilidad total: {total_profit:,.2f}" if total_profit else "💰 Utilidad total: 0")
    
    if total_revenue and total_profit:
        margin = (total_profit / total_revenue) * 100
        print(f"📈 Margen promedio: {margin:.2f}%")

print("\n" + "=" * 60)
print("✅ ETL completado exitosamente")
print("=" * 60)

job.commit()
