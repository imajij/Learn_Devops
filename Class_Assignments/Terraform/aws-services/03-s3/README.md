# 03 · S3 — Simple Storage Service (Storage)

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103 · [back to Terraform homework](../../README.md)

## What is S3?
S3 is AWS's **object storage**: you store files ("objects") of any type, from 0 B up to **5 TB each**, in containers ("buckets"), and access them over HTTPS with an API. Storage is effectively unlimited, durability is **99.999999999 % (11 nines)** because data is copied across at least 3 AZs, and you pay per GB-month, per request, and for data transfer out.
It is **not** a file system (no real folders, no in-place edits, no locking) and **not** a block disk (that is EBS). Since Dec 2020 it is **strongly read-after-write consistent**.

## Buckets
- A top-level container. Its name must be **globally unique** across all AWS accounts, 3–63 chars, lowercase letters/digits/hyphens/dots. My Terraform code checks this with a `validation` block.
- A bucket lives in **one region** you choose (latency, cost, data residency).
- Default limit: 10 000 buckets per account.
- Settings are per bucket: versioning, encryption, lifecycle, policy, logging, replication, Object Lock, static website hosting, event notifications.
- **New buckets are private** and have *Block Public Access* on by default.

## Objects
- An object = **key** (full name, e.g. `site/index.html`) + **data** + **metadata** (content-type, custom `x-amz-meta-*`) + optional **tags** + **version ID**.
- "Folders" are just key prefixes (`site/`) that the console displays as folders.
- Upload up to 5 GB in one PUT. Use **multipart upload** above ~100 MB (required above 5 GB).
- Address: `s3://bucket/key` or `https://bucket.s3.<region>.amazonaws.com/key`.
- Share privately with **pre-signed URLs** (time-limited links signed by someone who has access).

## Storage classes
| Class | For | Retrieval | Min duration |
|---|---|---|---|
| **S3 Standard** | Frequently accessed data (default) | ms | – |
| **S3 Intelligent-Tiering** | Unknown or changing access; AWS moves objects between tiers automatically | ms (archive tiers optional) | – |
| **S3 Standard-IA** | Infrequent access but fast when needed (backups) | ms, per-GB retrieval fee | 30 days |
| **S3 One Zone-IA** | Re-creatable infrequent data, **1 AZ only** | ms | 30 days |
| **S3 Express One Zone** | Ultra-low latency, single AZ, directory buckets | single-digit ms | – |
| **Glacier Instant Retrieval** | Archives read about once a quarter | ms | 90 days |
| **Glacier Flexible Retrieval** | Archives | minutes to 12 h | 90 days |
| **Glacier Deep Archive** | Compliance, 7–10 year retention, cheapest | 12–48 h | 180 days |

All except One Zone/Express keep the 11-nines durability across ≥ 3 AZs.

## Versioning
- When enabled, every overwrite creates a **new version**, and a delete only adds a **delete marker**. Old versions stay and can be restored. This protects against accidental deletes, overwrites and ransomware.
- States: *unversioned* (default) → *Enabled* → *Suspended* (can never return to unversioned).
- Old versions cost storage, so combine versioning with lifecycle rules that expire non-current versions.
- Required for **replication** (CRR/SRR) and **Object Lock**. **MFA Delete** can be added for extra protection.
- In my demo, `terraform show` showed a `version_id` on `hello.txt`. In the drift test, `aws s3 rm` only added a delete marker, and Terraform saw the object as gone and re-created it.

## Lifecycle policies
Rules (filtered by prefix or tag) that act automatically as objects age:
- **Transition** actions, e.g. Standard → Standard-IA after 30 days → Glacier Flexible after 90 → Deep Archive after 365.
- **Expiration** actions: delete objects after N days, delete **non-current versions** after N days, remove expired delete markers, **abort incomplete multipart uploads** (a common hidden cost).

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.demo.id
  rule {
    id     = "logs"
    status = "Enabled"
    filter { prefix = "logs/" }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }
}
```

## Encryption
- **In transit:** HTTPS/TLS. You can force it with a bucket policy condition `aws:SecureTransport = false → Deny`.
- **At rest (server-side):**
  - **SSE-S3** (AES-256, keys managed by S3): **default for all new objects since Jan 2023**. I also set it explicitly in my demo, and the CLI showed `SSEAlgorithm: AES256`.
  - **SSE-KMS**: keys in AWS KMS. Adds an audit trail in CloudTrail, key policies and rotation. Use *S3 Bucket Keys* to cut KMS request costs.
  - **DSSE-KMS**: dual-layer encryption for strict compliance.
  - **SSE-C**: you send your own key with every request.
- **Client-side:** you encrypt before uploading, so AWS only ever stores ciphertext.

## Bucket policies
A **resource-based JSON policy** attached to the bucket. It has a `Principal`, which makes it the way to grant **cross-account** or **public** access, or to enforce conditions for everyone:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::ajij-24bcs10103-tf-demo", "arn:aws:s3:::ajij-24bcs10103-tf-demo/*"],
    "Condition": { "Bool": { "aws:SecureTransport": "false" } }
  }]
}
```

Related controls: **Block Public Access** (4 switches, account- or bucket-level; it overrides any policy or ACL that would make data public, and all 4 were `true` in my demo), **Object Ownership = Bucket owner enforced** (disables legacy ACLs), IAM identity policies, VPC endpoint policies, and **Access Points** for large shared datasets.

## Common use cases
- **Static website / SPA hosting** (often behind CloudFront).
- Backups, disaster recovery and long-term archives (Glacier).
- **Data lake** for analytics (Athena, Glue, EMR, Redshift Spectrum).
- Application uploads (images, video) using pre-signed URLs.
- Logs: CloudTrail, ALB, VPC Flow Logs.
- CI/CD artifacts, Lambda deployment packages, Docker layer storage.
- **Terraform remote state** (versioned bucket + state locking).
