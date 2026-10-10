# Job 1: ETL de Ventas
aws glue create-job \
  --name erpnext-sale-etl \
  --role arn:aws:iam::329068432517:role/GlueServiceRole \
  --command "Name=glueetl,ScriptLocation=s3://erp-glue-scripts-329068432517/sales_etl.py,PythonVersion=3" \
  --glue-version "4.0" \
  --default-arguments '{"--db_name":"erpnext_db","--redshift_url":"jdbc:redshift://erp-warehouse.ccxb0dipqhm0.us-east-1.redshift.amazonaws.com:5439/erp_analytics","--redshift_user":"admin","--redshift_password":"erpnextDBPass123!","--s3_bucket":"erp-processed-data-329068432517-us-east-1"}' \
  --max-retries 0 \
  --timeout 60 \
  --region us-east-1
# Job 2: ETL de Análisis de Ventas
aws glue create-job \
  --name erp-analytics_v2 \
  --role arn:aws:iam::329068432517:role/GlueServiceRole \
  --command "Name=glueetl,ScriptLocation=s3://erp-glue-scripts-329068432517/analiytics_etl.py,PythonVersion=3" \
  --glue-version "4.0" \
  --default-arguments "{\"--db_name\":\"erpnext_db\",\"--redshift_url\":\"jdbc:redshift://erp-warehouse.ccxb0dipqhm0.us-east-1.redshift.amazonaws.com:5439/erp_analytics\",\"--redshift_user\":\"admin\",\"--redshift_password\":\"erpnextDBPass123!\",\"--s3_bucket\":\"erp-processed-data-329068432517-us-east-1\"}" \
  --max-retries 0 \
  --timeout 120 \
  --region us-east-1


# Ejecutar el primer ETL
aws glue start-job-run --job-name erpnext-sale-etl --region us-east-1

# Ejecutar el segundo ETL (después de que termine el primero)
aws glue start-job-run --job-name erp-analytics_v2 --region us-east-1



# Ver el estado de la ejecución
aws glue get-job-run \
  --job-name erpnext-sale-etl \
  --run-id jr_c4ed676005c567236d6f7ddd8dbec95233c30a727993ec191441ecb2c443b29f\
  --region us-east-1


aws glue get-job-run \
  --job-name erp-analytics_v2 \
  --run-id jr_f3eeb4d80312270471b837c49db7955f67939103bd67d02b4c261a801a7c21fe\
  --region us-east-1


# Ver logs en CloudWatch
# Ve a CloudWatch → Logs → /aws-glue/jobs/



aws ec2 authorize-security-group-ingress \
  --group-id sg-02a3bc8faccb8aae5\
  --protocol tcp \
  --port 3306 \
  --source-group sg-02a3bc8faccb8aae5 \
  --region us-east-1