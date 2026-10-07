# 02 · EC2 — Elastic Compute Cloud (Compute)

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103 · [back to Terraform homework](../../README.md)

## What is EC2?
EC2 provides **virtual servers ("instances") on demand** in AWS data centres. You choose the OS image, CPU/RAM size, disk, network and firewall, and pay **per second** (Linux) while the instance runs. It is AWS's core IaaS (infrastructure as a service) offering: AWS manages the hardware and hypervisor (Nitro), and you manage the OS and everything above it.

Pricing models: **On-Demand** (no commitment) · **Savings Plans / Reserved** (1–3 year commitment, up to ~70 % cheaper) · **Spot** (spare capacity, up to ~90 % cheaper, can be interrupted with 2 min notice) · **Dedicated Hosts** (a physical server, for licensing/compliance).

## AMI (Amazon Machine Image)
- The **template** an instance boots from: root-volume snapshot (OS + software), architecture (`x86_64`/`arm64`), virtualization type, and launch permissions.
- Sources: AWS (Amazon Linux 2023), vendors (Canonical Ubuntu, Red Hat, Windows), the **Marketplace**, or **your own** ("golden AMI" baked with Packer).
- AMIs are **regional** (copy them to use elsewhere) and have region-specific IDs (`ami-0abc…`). That is why Terraform usually looks them up with a `data "aws_ami"` filter rather than hard-coding the ID, as I did in the [project](../../../Cloud_and_Terraform_in_Action/terraform-infra/compute.tf).

## Instance types
Name format **`family` `generation` [`attributes`] . `size`**, e.g. `t3.micro`, `m7g.large`, `c6in.xlarge`.

| Family | Optimised for | Examples |
|---|---|---|
| **T** burstable | Low baseline CPU with burst credits; dev/test, small web apps | `t3.micro`, `t4g.small` |
| **M** general purpose | Balanced CPU/RAM | `m7i.large` |
| **C** compute | High CPU: batch, encoding, game servers | `c7g.xlarge` |
| **R / X** memory | Large RAM: databases, caches, analytics | `r7i.2xlarge` |
| **I / D** storage | Fast local NVMe / dense HDD | `i4i.large` |
| **P / G / Inf / Trn** accelerated | GPUs / ML chips | `g5.xlarge`, `p5.48xlarge` |

Attribute letters: `g` = Graviton (ARM, cheaper), `a` = AMD, `i` = Intel, `n` = more network, `d` = local NVMe disk. Size doubles each step (`large` → `xlarge` → `2xlarge`…).

## Key pairs
- SSH uses **public-key authentication**: AWS stores the **public key** and puts it in `~/.ssh/authorized_keys` at first boot. You keep the **private key** (`.pem`) and AWS never sees it again.
- Types: RSA or ED25519. Connect with `ssh -i key.pem ubuntu@<public-ip>` (username depends on the AMI: `ec2-user`, `ubuntu`, `admin`…).
- Lost key = lost SSH access. Modern alternatives that need **no key or open port 22**: **SSM Session Manager** and **EC2 Instance Connect**.

## Security Groups
- A **stateful virtual firewall at the instance (ENI) level**.
- **Allow rules only** (no deny). Default: all inbound blocked, all outbound allowed.
- **Stateful**: if inbound traffic is allowed, the reply goes out automatically.
- The source can be a CIDR or **another security group** (e.g. "DB SG allows 5432 only from the App SG").
- Several SGs per instance. Rule changes apply immediately.
- Example from my project: port 80 from `0.0.0.0/0`, port 22 only from one admin `/32`.

## EBS (Elastic Block Store)
- **Network-attached block disks** for instances. They persist independently of the instance (unless *delete on termination* is set, the default for the root volume).
- Live in **one AZ** and attach to instances in that AZ.
- Types: **gp3** (general SSD, default, 3 000 IOPS baseline, IOPS/throughput tunable), **io2** (provisioned IOPS for databases), **st1/sc1** (throughput/cold HDD).
- **Snapshots** are incremental backups stored in S3. They can be copied across regions and used to create AMIs or new volumes.
- Encryption at rest with KMS (enable "encrypt by default"). Volumes can be resized live.
- Not to be confused with **instance store**: local disks that are **lost on stop**.

## Public vs private IP
| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| From | Subnet CIDR (e.g. `10.10.1.4`) | AWS pool (e.g. `54.214.x.x`) | AWS pool, allocated to *your account* |
| Reachable from | Inside the VPC / peered / VPN | Internet (if SG + route allow) | Internet |
| On stop/start | **Kept** | **Released, new one on start** | **Kept** (static) |
| Cost | Free | Charged per hour (since 2024 all public IPv4 are billed) | Charged per hour |

An instance only gets a public IP if the subnet has `map_public_ip_on_launch` (or you ask for one), and it is only reachable if the subnet routes `0.0.0.0/0` to an **Internet Gateway**. The OS itself only ever sees the private IP; AWS does the 1:1 NAT.

## Instance lifecycle
```
           launch
             │
          pending ──► running ──reboot──► rebooting ──► running
                       │   ▲
                  stop │   │ start
                       ▼   │
                    stopping ──► stopped        (hibernate: RAM saved to EBS)
                       │
             terminate │ (from running or stopped)
                       ▼
                  shutting-down ──► terminated  (visible ~1 h, then gone)
```
- **Running**: billed for compute. **Stopped**: no compute bill, but EBS is still billed. The instance may move to new hardware on start, and the public IP changes.
- **Terminated** is permanent. Enable *termination protection* for important servers.
- `user_data` runs once at the first boot (cloud-init), e.g. to install nginx.

## Common use cases
- Web and application servers (often in an **Auto Scaling Group** behind a **Load Balancer**).
- Self-managed databases, caches, message brokers.
- CI/CD build agents, batch and HPC jobs on Spot.
- GPU machine-learning training and inference.
- Bastion hosts, VPN endpoints, dev/test environments, lift-and-shift of on-prem VMs.
- Kubernetes worker nodes (EKS node groups).
