#!/usr/bin/env bash
# Step 8: Terraform against LocalStack (container ajij-final-localstack, port 4577).
# Runs in a scratch copy so .terraform/ and state never land in the repo.
#   docker run -d --name ajij-final-localstack -p 4577:4566 \
#     -e SERVICES=s3,ec2,iam,sts,dynamodb,ssm,logs,ecr,secretsmanager localstack/localstack:4.0
source "$(dirname "$0")/common.sh"
export AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null   # never read ~/.aws
export TF_PLUGIN_CACHE_DIR="$WORK/tf-plugin-cache" TF_IN_AUTOMATION=1
mkdir -p "$TF_PLUGIN_CACHE_DIR" "$WORK/tf"
rsync -a --delete --exclude '.terraform*' --exclude '*.tfstate*' "$APP/terraform/" "$WORK/tf/"
cd "$WORK/tf"
case "${1:-up}" in
up)
  r "terraform version"
  r "curl -s localhost:4577/_localstack/health | jq -c '{edition, version, services: (.services | with_entries(select(.value != \"disabled\")) | keys)}'"
  r "terraform init -no-color | grep -E 'Initializing|Installed|Installing|successfully'"
  r "terraform validate -no-color"
  r "terraform plan -no-color -out=campusdesk.tfplan | grep -E '^  # |Plan:'"
  r "terraform apply -no-color -auto-approve campusdesk.tfplan | grep -E 'Creation complete|Apply complete' | sed -E 's/\\[id=[^]]{40,}\\]/[id=...]/'"
  r "terraform output -no-color"
  r "terraform plan -no-color -detailed-exitcode | tail -3; echo \"plan exit code: \${PIPESTATUS[0]} (0 = no drift)\""
  ;;
verify)
  AWS="docker exec ajij-final-localstack awslocal --region ap-south-1"
  r "$AWS ec2 describe-vpcs --filters Name=tag:Project,Values=campusdesk --query 'Vpcs[].[VpcId,CidrBlock]' --output text"
  r "$AWS ec2 describe-subnets --filters Name=tag:Project,Values=campusdesk --query 'Subnets[].[Tags[?Key==\`Name\`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output text | sort"
  r "$AWS ec2 describe-nat-gateways --query 'NatGateways[].[NatGatewayId,State,SubnetId]' --output text"
  r "$AWS s3api get-bucket-versioning --bucket campusdesk-dev-db-backups"
  r "$AWS dynamodb list-tables --query TableNames --output text"
  r "$AWS ssm get-parameters-by-path --path /campusdesk/dev --query 'Parameters[].[Name,Value]' --output text"
  r "terraform state list | wc -l"
  ;;
down)
  r "terraform plan -no-color -destroy | grep -E 'Plan:'"
  r "terraform destroy -no-color -auto-approve | grep -E 'Destroy complete|Destruction complete' | tail -5"
  r "terraform state list | wc -l"
  ;;
esac
# (appended) second apply: LocalStack 4.0 drops the tags of aws_subnet on create, so the first
# follow-up plan shows 4 in-place tag updates. One more apply converges; then the plan is empty.
if [ "${1:-}" = converge ]; then
  r "terraform apply -no-color -auto-approve | grep -E 'Modifications complete|Apply complete'"
  r "terraform plan -no-color -detailed-exitcode | tail -1; echo \"plan exit code: \${PIPESTATUS[0]} (0 = no drift)\""
fi
