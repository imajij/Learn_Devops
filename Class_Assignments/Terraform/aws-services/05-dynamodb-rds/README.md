# 05 · DynamoDB & RDS (Database Services)

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103 · [back to Terraform homework](../../README.md)

AWS offers both kinds of managed database: **DynamoDB** (serverless NoSQL key-value/document) and **RDS** (managed relational SQL). "Managed" means AWS handles hardware, patching, backups and replication.

---

## DynamoDB

### NoSQL
- **NoSQL** = "not only SQL": no fixed schema, no joins, and data is modelled around the **access patterns** (the queries you will run), not around normalised tables.
- DynamoDB is a **fully managed, serverless key-value and document database**. There are no servers or instances, it gives **single-digit-millisecond latency at any scale**, and it replicates automatically across 3 AZs.
- Capacity modes: **On-demand** (pay per request, zero planning) or **Provisioned** (set read/write capacity units, with auto scaling; cheaper for steady load).
- Reads are eventually consistent by default (half the cost). **Strongly consistent** reads and **ACID transactions** (`TransactWriteItems`) are available.

### Tables
- A table is a collection of items. You only define the **primary key** (plus any secondary indexes) when creating it. Every other attribute is free-form.
- Extra features: **GSI/LSI** secondary indexes (query by other attributes), **TTL** (auto-delete expired items), **Streams** (change log → Lambda), **Global Tables** (multi-region active-active), **PITR** backups (any second in the last 35 days).

### Items
- An item is one record (like a row), identified uniquely by its primary key. Maximum size **400 KB**.
- Items in the same table can have completely different attributes.

### Attributes
- Name/value pairs in an item (like columns, but optional per item).
- Types: scalar **S** (string), **N** (number), **B** (binary), **BOOL**, **NULL** · document **M** (map), **L** (list) · sets **SS / NS / BS**.

```json
{ "UserId": "u#101", "OrderDate": "2026-10-07", "Total": 499, "Items": ["book", "pen"], "Address": {"city": "Mumbai"} }
```

### Partition key
- The **mandatory** part of the primary key (also called the *hash key*). DynamoDB hashes it to decide **which physical partition** stores the item.
- If it is the only key (a *simple primary key*), it must be unique per item.
- Choose a **high-cardinality** key with evenly spread traffic (`UserId`, `OrderId`). A low-cardinality key (`status = "active"`) creates **hot partitions** and throttling.

### Sort key
- Optional second part of the primary key (*range key*). Items with the same partition key are stored **together, sorted** by it. Partition + sort key together must be unique (a *composite key*).
- It enables range queries inside one partition: `UserId = "u#101" AND OrderDate BETWEEN "2026-01-01" AND "2026-12-31"`, `begins_with(SK, "ORDER#")`, newest-first, top-N.

```hcl
resource "aws_dynamodb_table" "orders" {
  name         = "orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"     # partition key
  range_key    = "OrderDate"  # sort key
  attribute {
    name = "UserId"
    type = "S"
  }
  attribute {
    name = "OrderDate"
    type = "S"
  }
}
```

### DynamoDB use cases
- Session stores, user profiles, shopping carts.
- Gaming leaderboards and player state.
- IoT and time-series events, clickstreams (with TTL).
- Serverless back ends (API Gateway + Lambda + DynamoDB).
- Metadata and catalogues at huge scale (Amazon.com, Prime Day peaks).
- **Terraform state locking** table (`LockID` key) next to an S3 state bucket.

---

## RDS (Relational Database Service)

### Relational database
- Data lives in **tables with a fixed schema** (rows and typed columns), linked by **primary/foreign keys**, and queried with **SQL** (joins, aggregations).
- Provides **ACID** transactions, constraints and normalisation, which makes it ideal when data integrity and complex queries matter.
- **RDS** runs these engines for you: provisioning, OS and engine patching, automated backups, monitoring, Multi-AZ failover and read replicas. You still design the schema, tune queries and pick the size. No SSH or OS access (except RDS Custom).

### Supported engines
**MySQL**, **PostgreSQL**, **MariaDB**, **Oracle** (BYOL or license-included), **Microsoft SQL Server**, **IBM Db2**, and **Amazon Aurora** (MySQL- and PostgreSQL-compatible). Aurora is AWS's cloud-native engine: storage auto-grows to 128 TB, 6 copies across 3 AZs, up to 15 low-lag replicas, and a **Serverless v2** option.

### DB instances
- A **DB instance** is an isolated database environment: one engine, one endpoint (`mydb.xxxx.ap-south-1.rds.amazonaws.com:5432`), and one or more databases inside.
- Instance classes like EC2: **`db.t4g/t3`** (burstable, dev), **`db.m*`** (general), **`db.r*` / `db.x*`** (memory-optimised).
- Storage on EBS: **gp3**, **io1/io2** (provisioned IOPS), magnetic (legacy). *Storage autoscaling* grows it automatically.
- Launched into a **DB subnet group** (private subnets in ≥ 2 AZs). Configuration through **parameter groups** and **option groups**.

### Security
- **Network:** put it in **private subnets**, set `publicly_accessible = false`, and use a security group that allows port 3306/5432 **only from the app servers' SG**.
- **Encryption at rest:** KMS (set at creation; covers storage, backups, snapshots, replicas). **In transit:** SSL/TLS (can be forced with `rds.force_ssl` / `require_secure_transport`).
- **Authentication:** master user password stored in **Secrets Manager** with automatic rotation (`manage_master_user_password`), plus **IAM database authentication** (short-lived tokens instead of passwords) for MySQL/PostgreSQL.
- **IAM** policies control who can create, modify or delete instances. Enable *deletion protection*.
- **Auditing:** CloudTrail for API calls, engine audit logs to CloudWatch Logs, and Performance Insights / Database Activity Streams.

### Backups
- **Automated backups:** a daily snapshot plus transaction logs every ~5 min, retained **1–35 days**. This allows **point-in-time recovery (PITR)** to any second in the window. Restoring always creates a **new instance**.
- **Manual snapshots:** kept until you delete them. Can be copied to other regions/accounts and shared.
- **AWS Backup** can manage policies centrally. Take a final snapshot before deleting (`skip_final_snapshot = false`).

### Multi-AZ
- **High availability / disaster recovery**, not scaling.
- A **synchronous standby** replica in another AZ. You cannot read from it (classic Multi-AZ instance).
- On failure (AZ outage, instance failure, patching) RDS **fails over automatically** in about 60–120 s by flipping the **same DNS endpoint** to the standby, so the app only needs to reconnect.
- A **Multi-AZ DB cluster** option (MySQL/PostgreSQL) has 1 writer + **2 readable standbys** and faster failover (~35 s).

### Read replicas
- **Read scaling**: up to **15** replicas (MySQL, MariaDB, PostgreSQL; Oracle/SQL Server with limits), using **asynchronous** replication, so reads may lag slightly.
- Each replica has **its own endpoint**. The application sends read-heavy queries (reports, analytics, product listings) there and writes to the primary.
- Can be **cross-region** (lower latency for distant users, DR) and can be **promoted** to a standalone writable database.
- A replica can itself be Multi-AZ.

| | Multi-AZ | Read replica |
|---|---|---|
| Goal | Availability (failover) | Performance (scale reads) |
| Replication | Synchronous | Asynchronous |
| Readable? | No (instance) / yes (cluster) | Yes |
| Endpoint | Same endpoint after failover | Separate endpoint per replica |
| Region | Same region, different AZ | Same or cross-region |

### RDS use cases
- Traditional web and mobile app back ends (WordPress, Django, Rails, Spring apps).
- E-commerce orders, payments, banking: anything that needs transactions and integrity.
- ERP, CRM and SaaS multi-tenant systems.
- Reporting with complex joins, often from read replicas.
- Lift-and-shift of on-prem Oracle / SQL Server / MySQL.

---

## DynamoDB vs RDS — which one?

| | DynamoDB | RDS |
|---|---|---|
| Model | Key-value / document (NoSQL) | Relational tables (SQL) |
| Schema | Flexible, only the key is fixed | Fixed, enforced |
| Queries | By key / index, no joins | Any SQL, joins, aggregations |
| Scaling | Automatic, practically unlimited, serverless | Vertical (bigger instance) + read replicas; Aurora Serverless |
| Ops | Nothing to manage | Choose instance size, maintenance windows, version upgrades |
| Pick it when | Known access patterns, massive scale, low latency | Relationships, ad-hoc queries, strong integrity |
