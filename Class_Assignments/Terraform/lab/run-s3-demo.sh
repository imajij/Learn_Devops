#!/usr/bin/env bash
# Runs the full Terraform workflow for terraform-s3-demo against LocalStack.
# Usage: bash lab/run-s3-demo.sh   (from the Terraform/ folder; LocalStack must be on :4566)
set -u
. ~/devops-lab/terraform/env.sh          # dummy test/test keys + AWS_ENDPOINT_URL=http://localhost:4566
LAB="$(cd "$(dirname "$0")" && pwd)"
cd "$LAB/../terraform-s3-demo"
r(){ echo "\$ $*"; eval "$@" 2>&1; echo; }
c(){ echo "### $*"; }

{ r terraform version; r terraform init -no-color; r ls -a; } > "$LAB/01-init.txt"
{ c "fmt rewrites badly formatted files and prints their names"; r terraform fmt; r 'terraform fmt -check; echo "fmt -check exit code: $?"'; r terraform validate -no-color; } > "$LAB/02-fmt-validate.txt"
{ r terraform plan -no-color -out=tfplan; } > "$LAB/03-plan.txt"
{ r terraform apply -no-color tfplan; } > "$LAB/04-apply.txt"
{ r terraform state list; r terraform show -no-color; } > "$LAB/05-show.txt"
{ r terraform output -no-color; r terraform output -raw bucket_arn; echo; r terraform output -json; } > "$LAB/06-output.txt"
{ c "verify with the AWS CLI (pointed at LocalStack via AWS_ENDPOINT_URL)"
  r aws s3 ls
  r aws s3 ls s3://ajij-24bcs10103-tf-demo/
  r aws s3 cp s3://ajij-24bcs10103-tf-demo/hello.txt -
  r aws s3api get-bucket-versioning --bucket ajij-24bcs10103-tf-demo
  r aws s3api get-bucket-encryption --bucket ajij-24bcs10103-tf-demo --query 'ServerSideEncryptionConfiguration.Rules[0]'
  r aws s3api get-public-access-block --bucket ajij-24bcs10103-tf-demo
  r aws s3api get-bucket-tagging --bucket ajij-24bcs10103-tf-demo --output text
  c "a second plan right after apply must be empty (state == real world)"
  r 'terraform plan -no-color -detailed-exitcode | tail -2; echo "exit code: ${PIPESTATUS[0]}"'; } > "$LAB/07-verify-awscli.txt"
{ c "DRIFT: someone changes the bucket by hand, outside Terraform"
  r "aws s3api put-bucket-tagging --bucket ajij-24bcs10103-tf-demo --tagging 'TagSet=[{Key=Environment,Value=prod}]'"
  r aws s3 rm s3://ajij-24bcs10103-tf-demo/hello.txt
  c "terraform plan refreshes state from the real API and shows the difference"
  r terraform plan -no-color
  c "plan -detailed-exitcode returns 2 when there is drift, handy for a nightly CI drift check"
  r 'terraform plan -no-color -detailed-exitcode >/dev/null; echo "exit code: $?"'
  c "apply puts the bucket back to what the code says"
  r terraform apply -no-color -auto-approve
  r 'terraform plan -no-color -detailed-exitcode | tail -3; echo "exit code: ${PIPESTATUS[0]}"'; } > "$LAB/08-drift.txt"
{ r terraform plan -destroy -no-color; r terraform destroy -no-color -auto-approve; r terraform state list; r aws s3 ls; r 'echo "buckets left: $(aws s3 ls | wc -l)"'; } > "$LAB/09-destroy.txt"
rm -f tfplan
