#!/usr/bin/env bash
# End-to-end Terraform run of terraform-infra/ against LocalStack (localhost:4566).
# Usage: bash lab/run.sh   (from Cloud_and_Terraform_in_Action/)
set -u
. ~/devops-lab/terraform/env.sh          # dummy test/test keys + AWS_ENDPOINT_URL=http://localhost:4566
LAB="$(cd "$(dirname "$0")" && pwd)"; IMG="../images"   # relative to terraform-infra/
cd "$LAB/../terraform-infra"
r(){ echo "\$ $*"; eval "$@" 2>&1; echo; }
c(){ echo "### $*"; }
V="--query"

{ r 'curl -s localhost:4566/_localstack/health | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[\"edition\"], d[\"version\"], {k:v for k,v in d[\"services\"].items() if v!=\"disabled\"})"'
  r terraform version; r terraform init -no-color; r 'terraform fmt -check -recursive; echo "fmt exit code: $?"'; r terraform validate -no-color; } > "$LAB/01-init-validate.txt"
{ r terraform plan -no-color -out=tfplan; } > "$LAB/02-plan.txt"
{ r terraform apply -no-color tfplan; } > "$LAB/03-apply.txt"
{ r terraform state list; r terraform state show -no-color aws_instance.web; r terraform state show -no-color aws_route_table.public; } > "$LAB/04-state.txt"
{ r terraform output -no-color; r terraform output -raw instance_public_ip; echo; } > "$LAB/05-output.txt"
{ c "verify every resource with the AWS CLI (AWS_ENDPOINT_URL points it at LocalStack)"
  r "aws ec2 describe-vpcs --filters Name=tag:Project,Values=ajij-cloud-tf $V 'Vpcs[].[VpcId,CidrBlock,State,Tags[?Key==\`Name\`]|[0].Value]' --output table"
  r "aws ec2 describe-subnets --filters Name=vpc-id,Values=\$(terraform output -raw vpc_id) $V 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table"
  r "aws ec2 describe-internet-gateways --filters Name=tag:Project,Values=ajij-cloud-tf $V 'InternetGateways[].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' --output table"
  r "aws ec2 describe-route-tables --filters Name=tag:Project,Values=ajij-cloud-tf $V 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' --output table"
  r "aws ec2 describe-security-groups --filters Name=group-name,Values=ajij-cloud-tf-web-sg $V 'SecurityGroups[].IpPermissions[].[FromPort,ToPort,IpProtocol,IpRanges[0].CidrIp]' --output table"
  r "aws ec2 describe-instances --filters Name=tag:Project,Values=ajij-cloud-tf $V 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,ImageId,PrivateIpAddress,PublicIpAddress,IamInstanceProfile.Arn]' --output table"
  r aws s3 ls s3://ajij-24bcs10103-app-assets --recursive
  r aws s3 cp s3://ajij-24bcs10103-app-assets/site/index.html -
  r "aws iam get-role --role-name ajij-cloud-tf-ec2-role $V 'Role.[RoleName,Arn]' --output text"
  r "aws iam get-role-policy --role-name ajij-cloud-tf-ec2-role --policy-name read-app-assets $V PolicyDocument.Statement"
} > "$LAB/06-verify-awscli.txt"
{ c "a second plan right after apply should be empty. Here it is not (LocalStack quirk, see README):"
  r 'terraform plan -no-color -detailed-exitcode; echo "exit code: $?"'
  r "aws ec2 describe-subnets --filters Name=vpc-id,Values=\$(terraform output -raw vpc_id) $V 'Subnets[].Tags' --output text"
  c "apply once more: provider uses CreateTags for the update, which LocalStack does honour"
  r 'terraform apply -no-color -auto-approve | sed "/^Outputs:/,\$d"'
  r "aws ec2 describe-subnets --filters Name=vpc-id,Values=\$(terraform output -raw vpc_id) $V 'Subnets[].Tags' --output text"
  r 'terraform plan -no-color -detailed-exitcode | tail -2; echo "exit code: ${PIPESTATUS[0]}"'; } > "$LAB/06b-second-plan.txt"
{ c "dependency graph: terraform graph prints DOT, graphviz 'dot' renders it"
  r 'terraform graph > graph.dot && wc -l graph.dot'
  r "grep -- '->' graph.dot | sed 's/\"//g' | sort"
  r "dot -Tpng -Gdpi=110 graph.dot -o $IMG/terraform-graph.png && dot -Tsvg graph.dot -o $IMG/terraform-graph.svg && ls -l $IMG/terraform-graph.*"
  r 'rm graph.dot'; } > "$LAB/07-graph.txt"
{ r terraform plan -destroy -no-color -out=destroy.tfplan; r terraform apply -no-color destroy.tfplan; } > "$LAB/08-destroy.txt"
{ c "after destroy: state is empty and the AWS CLI finds nothing left"
  r terraform state list
  r 'echo "vpcs tagged Project=ajij-cloud-tf: $(aws ec2 describe-vpcs --filters Name=tag:Project,Values=ajij-cloud-tf --query "length(Vpcs)")"'
  r 'echo "running/pending instances: $(aws ec2 describe-instances --filters Name=tag:Project,Values=ajij-cloud-tf Name=instance-state-name,Values=pending,running --query "length(Reservations)")"'
  r "aws ec2 describe-instances --filters Name=tag:Project,Values=ajij-cloud-tf $V 'Reservations[].Instances[].[InstanceId,State.Name]' --output text"
  r 'aws s3 ls; echo "buckets: $(aws s3 ls | wc -l | tr -d " ")"'
  r 'aws iam get-role --role-name ajij-cloud-tf-ec2-role'; } > "$LAB/09-after-destroy.txt"
rm -f tfplan destroy.tfplan
