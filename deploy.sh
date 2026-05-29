#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-erpnext-production}"
TEMPLATE_FILE="${TEMPLATE_FILE:-template_erp.yaml}"
REGION="${AWS_REGION:-us-east-1}"
VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo latest)}"

KEY_PAIR_NAME="${KEY_PAIR_NAME:-erpnext-instace-key.pem}"
SITE_DOMAIN="${SITE_DOMAIN:-erp.theartificialmachine.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ERP_NEXT_AMI_ID="${ERP_NEXT_AMI_ID:-}"

function usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  deploy      Create or update the CloudFormation stack
  destroy     Delete the stack
  validate    Validate the CloudFormation template
  version     Print the deployment version

Environment variables:
  KEY_PAIR_NAME      SSH key pair name (required for deploy)
  SITE_DOMAIN        ERPNext domain (default: erp.example.com)
  ADMIN_PASSWORD     ERPNext admin password (required for deploy)
  ERP_NEXT_AMI_ID    AMI ID imported from ERPNext OVA (optional)
  STACK_NAME         CloudFormation stack name (default: erpnext-production)
  TEMPLATE_FILE      Template file path (default: template_erp.yaml)
  AWS_REGION         AWS region (default: us-east-1)
  VERSION            Deployment version tag (default: git describe)
EOF
  exit 1
}

function ensure_required() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "ERROR: Missing required environment variable $name" >&2
    usage
  fi
}

function build_parameters() {
  local params=()

  params+=(ParameterKey=KeyPairName,ParameterValue="$KEY_PAIR_NAME")
  params+=(ParameterKey=SiteDomain,ParameterValue="$SITE_DOMAIN")
  params+=(ParameterKey=AdminPassword,ParameterValue="$ADMIN_PASSWORD")

  if [[ -n "$ERP_NEXT_AMI_ID" ]]; then
    params+=(ParameterKey=ERPNextAmiId,ParameterValue="$ERP_NEXT_AMI_ID")
  fi

  printf '%s\n' "${params[@]}"
}

function stack_exists() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1
}

function create_stack() {
  echo "Creating stack $STACK_NAME in $REGION with version $VERSION"
  aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters $(build_parameters) \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --tags Key=Version,Value="$VERSION" \
    --region "$REGION"
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo "Stack created: $STACK_NAME"
}

function update_stack() {
  echo "Updating stack $STACK_NAME in $REGION with version $VERSION"
  set +e
  output=$(aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters $(build_parameters) \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --tags Key=Version,Value="$VERSION" \
    --region "$REGION" 2>&1)
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    if echo "$output" | grep -q "No updates are to be performed"; then
      echo "No updates to apply for stack $STACK_NAME"
      return 0
    fi
    echo "$output" >&2
    return $status
  fi

  echo "$output"
  aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo "Stack updated: $STACK_NAME"
}

function deploy_stack() {
  ensure_required KEY_PAIR_NAME "$KEY_PAIR_NAME"
  ensure_required ADMIN_PASSWORD "$ADMIN_PASSWORD"

  if stack_exists; then
    update_stack
  else
    create_stack
  fi
}

function destroy_stack() {
  echo "Deleting stack $STACK_NAME in $REGION"
  aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
  echo "Stack deleted: $STACK_NAME"
}

function validate_template() {
  echo "Validating template $TEMPLATE_FILE"
  aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"
}

function print_version() {
  echo "$VERSION"
}

if [[ $# -lt 1 ]]; then
  usage
fi

case "$1" in
  deploy|create|update)
    deploy_stack
    ;;
  destroy|delete)
    destroy_stack
    ;;
  validate)
    validate_template
    ;;
  version)
    print_version
    ;;
  *)
    usage
    ;;
esac