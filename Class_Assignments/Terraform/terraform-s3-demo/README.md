# terraform-s3-demo

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103

Creates one S3 bucket with Terraform, plus the settings a bucket should always have: versioning, default encryption (SSE-S3 / AES-256), a public-access block, and one test object `hello.txt`.
It was run against **LocalStack 4.0** (AWS emulator in Docker) instead of a real AWS account. Screenshots and the full output of every command are in the [parent README](../README.md) and [`../lab/`](../lab/).

```
terraform-s3-demo/
├── main.tf             # aws_s3_bucket + versioning + encryption + public access block + aws_s3_object
├── variables.tf        # aws_region, bucket_name (validated), environment, enable_versioning, localstack_endpoint
├── outputs.tf          # bucket_name, bucket_arn, bucket_region, versioning_status, object_url
├── provider.tf         # terraform{} version pins + provider "aws" (LocalStack endpoints, default_tags)
├── terraform.tfvars    # actual values (bucket_name = "ajij-24bcs10103-tf-demo", region ap-south-1)
├── .terraform.lock.hcl # provider version + checksums (committed)
└── .gitignore          # .terraform/, *.tfstate*, plan files
```

## Workflow

Start LocalStack first: `docker run -d --name ajij-localstack -p 4566:4566 localstack/localstack:4.0`.

| # | Command | What it does | Result in my run |
|---|---|---|---|
| 1 | `terraform init` | Downloads the provider plugin into `.terraform/`, writes the lock file, sets up the backend | `hashicorp/aws v5.100.0` installed |
| 2 | `terraform fmt` | Rewrites `.tf` files to the canonical style | fixed `main.tf` (I mis-indented a line on purpose) |
| 3 | `terraform validate` | Checks syntax, types and references offline | `Success! The configuration is valid.` |
| 4 | `terraform plan -out=tfplan` | Compares code with state and real infra, shows the diff, saves it | `Plan: 5 to add, 0 to change, 0 to destroy.` |
| 5 | `terraform apply tfplan` | Executes exactly the saved plan | `Apply complete! Resources: 5 added` |
| 6 | `terraform show` | Prints the state in readable form | real ARN, region, tags, object `version_id` |
| 7 | `terraform output` | Prints the output values (`-raw`, `-json` for scripts) | `bucket_arn = "arn:aws:s3:::ajij-24bcs10103-tf-demo"` … |
| 8 | `terraform destroy` | Deletes everything in the state, in reverse dependency order | `Destroy complete! Resources: 5 destroyed.` |

Extra checks I ran: AWS CLI verification of every setting, a second `plan` after apply (no changes), and a **drift test** (changed tags and deleted the object by hand; `plan` detected both and `apply` repaired them). See the [parent README](../README.md#7-bonus--drift-detection).

## Key ideas

- **Declarative:** the `.tf` files describe the *end state*. Terraform works out the API calls (create, update in place, or replace).
- **State (`terraform.tfstate`)** maps each resource address (`aws_s3_bucket.demo`) to the real object (`ajij-24bcs10103-tf-demo`). Never edit it by hand, never commit it (it can contain secrets), and use a remote backend for teams.
- **Implicit dependencies:** `bucket = aws_s3_bucket.demo.id` tells Terraform the bucket must exist first. The four child resources were then created in parallel.
- **Variables + tfvars:** the same code can build a `dev` or `prod` bucket by changing only `terraform.tfvars`.

## Real AWS instead of LocalStack

In `provider.tf`, delete `access_key`, `secret_key`, the three `skip_*` flags, `s3_use_path_style` and the `endpoints {}` block. Log in with `aws configure` (or SSO), and pick a globally unique `bucket_name`. The provider can then go back to `~> 6.0` (it is pinned to 5.x only because 6.x tags buckets during `CreateBucket`, which LocalStack 4.0 ignores; details in the [parent README](../README.md#problem-i-hit-provider-6x-and-localstack-tags)).
