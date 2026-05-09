aws cloudformation create-stack \
  --stack-name erpnext-production \
  --template-body file://erpnext-template.yaml \
  --parameters \
      ParameterKey=KeyPairName,ParameterValue=my-key-pair \
      ParameterKey=SiteDomain,ParameterValue=erp.midominio.com \
      ParameterKey=AdminPassword,ParameterValue=MiPasswordSeguro!123 \
  --capabilities CAPABILITY_NAMED_IAM