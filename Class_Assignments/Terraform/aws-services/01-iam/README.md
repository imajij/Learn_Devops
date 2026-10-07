# 01 · IAM — Identity and Access Management (Governance)

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103 · [back to Terraform homework](../../README.md)

## What is IAM?
IAM is the AWS service that decides **who** (authentication) can do **what** on **which resource** (authorization) in an AWS account. It is **global** (not tied to a region) and **free**. Every AWS API call, whether from the console, the CLI, Terraform or an SDK, is checked against IAM before it runs.

```
Principal (user / role)  ──request──►  IAM evaluates all policies  ──► Allow or Deny
   "who"                    "action + resource + conditions"
```

## Users
- An **IAM user** is a long-lived identity for **one person or one application**, with its own credentials:
  - a console password (plus MFA), and/or
  - **access keys** (`AKIA…` key ID + secret) for the CLI and API.
- A new user has **no permissions at all** until a policy grants them.
- The **root user** (the account's sign-up email) can do everything and cannot be restricted. Use it only for a few account-level tasks, protect it with MFA, and never create access keys for it.

## Groups
- A **group** is a collection of users. Policies attached to the group apply to every member (e.g. `Developers`, `Admins`, `ReadOnly`).
- Users can be in several groups. Groups **cannot be nested** and **cannot be a principal** in a policy (you cannot "log in as a group").
- Managing permissions per group instead of per user scales much better: a new joiner is just added to the right group.

## Roles
- A **role** is an identity with permissions but **no long-term credentials**. Someone or something **assumes** it and gets **temporary credentials** from STS (expire in 15 min to 12 h).
- A role has two policies:
  - the **trust policy**: *who may assume it*, e.g. `ec2.amazonaws.com`, a Lambda, another account, or SSO users
  - the **permission policy**: *what it may do*
- Typical uses: an EC2 instance profile, Lambda execution roles, cross-account access, federated or SSO logins, and CI/CD (GitHub Actions OIDC → role).
- I used one in the [Cloud & Terraform project](../../../Cloud_and_Terraform_in_Action/terraform-infra/iam.tf): the EC2 instance assumes a role that may only read one S3 bucket, so no access keys are stored on the server.

## Policies
A policy is a JSON document of **statements**:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "ReadAppAssets",
    "Effect": "Allow",
    "Action": ["s3:GetObject"],
    "Resource": "arn:aws:s3:::ajij-24bcs10103-app-assets/*",
    "Condition": { "Bool": { "aws:SecureTransport": "true" } }
  }]
}
```

| Type | Attached to | Notes |
|---|---|---|
| **AWS-managed** | users/groups/roles | Written by AWS (e.g. `ReadOnlyAccess`, `AmazonS3FullAccess`). Convenient but often too broad |
| **Customer-managed** | users/groups/roles | Your own reusable policy, versioned |
| **Inline** | one identity | Lives and dies with that identity (e.g. `aws_iam_role_policy` in Terraform) |
| **Resource-based** | a resource (S3 bucket policy, KMS key policy, SQS…) | Has a `Principal` field, enables cross-account access |
| **Permission boundary** | user/role | The *maximum* permissions an identity can ever get |
| **SCP** (AWS Organizations) | account / OU | Guardrails for whole accounts, e.g. "no one may leave ap-south-1" |

## Permissions — how a request is evaluated
1. Everything starts as **implicit deny**.
2. If **any** applicable policy has an **explicit `Deny`**, the answer is deny, and nothing can override it.
3. Otherwise, an `Allow` in an identity or resource policy grants the request, as long as SCPs, permission boundaries and session policies also allow it.
4. No allow anywhere → denied.

So: **explicit deny > explicit allow > default deny.** The IAM Policy Simulator and `aws iam simulate-principal-policy` test this without making real calls.

## Least privilege
Give each identity **only the actions and resources it needs, for only as long as it needs them**:
- Name specific actions (`s3:GetObject`), not `s3:*`. Name specific ARNs, not `"Resource": "*"`.
- Add conditions (source IP / VPC, MFA present, tags, time).
- Start small and widen when something is denied. **IAM Access Analyzer** can generate a policy from CloudTrail activity and list unused permissions.
- Prefer short-lived role credentials over permanent keys.

## IAM best practices
1. Lock away the **root user**: MFA, no access keys, use it only for account tasks.
2. **MFA** for every human user.
3. Humans sign in through **IAM Identity Center (SSO)** or federation, not individual IAM users with keys.
4. Workloads use **roles** (instance profiles, Lambda roles, OIDC for CI), never hard-coded keys.
5. If access keys are unavoidable: **rotate** them, never commit them to git (scan with `gitleaks`), and delete unused ones (credential report).
6. Grant permissions through **groups/roles**, not to single users.
7. **Least privilege** + permission boundaries + SCPs as guardrails.
8. A strong password policy.
9. Audit regularly: **CloudTrail** (who did what), **Access Analyzer** (external or unused access), **credential report** / last-accessed data.
10. Manage IAM as code (Terraform) so changes are reviewed in pull requests.

## Common use cases
- Separate permissions for teams: Admins, Developers (deploy to dev only), Auditors (read-only).
- An EC2 instance or Lambda reading S3 or DynamoDB through a **role**.
- **CI/CD** (GitHub Actions, Jenkins) deploying with an OIDC-federated role, with no stored secrets.
- **Cross-account access**, e.g. a security account reading logs from all workload accounts.
- Temporary access for a contractor with an expiring role session.
- Enforcing rules: "MFA required to delete", "only `ap-south-1`", "only tagged resources".
