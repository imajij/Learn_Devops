# 04 · VPC — Virtual Private Cloud (Networking)

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103 · [back to Terraform homework](../../README.md)

## What is a VPC?
A VPC is **your own logically isolated private network inside an AWS region**. You choose its IP range, split it into subnets, decide how traffic is routed, and control what can reach what. Resources such as EC2, RDS, load balancers and Lambda-in-VPC get private IPs from it. A VPC spans **all AZs of one region**, and each subnet lives in exactly **one AZ**. Every account has a *default VPC* per region (`172.31.0.0/16`, public subnets), but production uses custom VPCs, usually built with Terraform as in my [project](../../../Cloud_and_Terraform_in_Action/terraform-infra/network.tf).

```
Region ap-south-1
└── VPC 10.10.0.0/16
    ├── AZ a: public subnet 10.10.1.0/24  ── route 0.0.0.0/0 → Internet Gateway
    │                  └─ NAT Gateway
    ├── AZ a: private subnet 10.10.11.0/24 ── route 0.0.0.0/0 → NAT Gateway
    └── AZ b: … (same again, for high availability)
```

## CIDR
- **Classless Inter-Domain Routing** notation `a.b.c.d/n`: the first *n* bits are the network part, and the rest are host addresses. Number of addresses = 2^(32−n).
  - `/16` = 65 536 · `/20` = 4 096 · `/24` = 256 · `/28` = 16 · `/32` = exactly one IP (used in SG rules for one admin IP)
- VPC size must be between **/16 and /28**. Use private RFC 1918 ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Plan ranges so they **don't overlap** with other VPCs or on-prem networks you may want to peer or VPN with later. Extra CIDR blocks and IPv6 `/56` can be added.

## Subnets
- A slice of the VPC CIDR in **one AZ** (e.g. `10.10.1.0/24` in `ap-south-1a`).
- AWS **reserves 5 IPs per subnet**: network address, `.1` VPC router, `.2` DNS, `.3` future use, and the last (broadcast). A `/24` therefore has **251** usable addresses. My EC2 got `10.10.1.4`, the first free one.
- Spread subnets over at least 2 AZs for high availability.

## Route tables
- A set of rules `destination CIDR → target` that decides where packets leaving a subnet go. The most specific match wins.
- Every route table has the implicit **`local`** route (VPC CIDR → local), so all subnets in a VPC can reach each other.
- Every subnet is associated with exactly one route table (the **main** one if you don't choose). My project's table, as shown by the AWS CLI:

| Destination | Target | Meaning |
|---|---|---|
| `10.10.0.0/16` | `local` | traffic inside the VPC |
| `0.0.0.0/0` | `igw-…` | everything else goes to the internet |

- Other targets: NAT Gateway, VPC peering, Transit Gateway, VPN gateway, VPC endpoints (gateway type for S3/DynamoDB), network interfaces.

## Internet Gateway (IGW)
- A horizontally scaled, highly available, free AWS component **attached to a VPC** (one per VPC). It lets traffic flow between the VPC and the internet in **both directions**.
- It also does the 1:1 NAT between an instance's private IP and its **public / Elastic IP**.
- Three things are needed for internet access: an IGW attached, a route `0.0.0.0/0 → igw`, and the instance having a public IP (plus SG/NACL allowing the traffic).

## NAT Gateway
- Lets instances in **private subnets** start **outbound** connections to the internet (OS updates, calling external APIs) while **nothing from the internet can start a connection to them**.
- It sits in a **public subnet**, has an Elastic IP, and the private subnet's route table sends `0.0.0.0/0 → nat-…`.
- Managed by AWS and scales to 100 Gbps, but it is **AZ-scoped**: for HA, use one per AZ. It is also **paid** (hourly plus per GB processed), a common surprise on the bill.
- Cheaper alternatives: NAT instance (self-managed EC2), or **VPC endpoints** so S3/DynamoDB traffic avoids NAT completely.

## Security Groups
- A **stateful** firewall on each **network interface** (instance level).
- **Allow rules only**. All rules are evaluated together. Return traffic is automatically allowed.
- Sources and destinations can be CIDRs, prefix lists or **other security groups** (great for tiers: ALB-SG → App-SG → DB-SG).
- Default: deny all inbound, allow all outbound.

## Network ACLs (NACLs)
- A **stateless** firewall at the **subnet** boundary.
- **Allow and Deny** rules, evaluated **in number order**, and the first match wins (`*` at the end denies everything else).
- Stateless means return traffic needs its own rule: allow **ephemeral ports 1024–65535** outbound or inbound.
- The default NACL allows everything. A custom NACL denies everything until you add rules.
- Use it as a coarse second layer, e.g. block a known-bad IP range for a whole subnet.

| | Security Group | Network ACL |
|---|---|---|
| Level | Instance / ENI | Subnet |
| State | **Stateful** | **Stateless** |
| Rules | Allow only | Allow + Deny |
| Evaluation | All rules together | In order, first match wins |
| Applies to | Only resources that use the SG | Everything in the subnet |

## Public vs private subnet
There is no "public" checkbox: a subnet is **public because of its route table**.

| | Public subnet | Private subnet |
|---|---|---|
| Default route | `0.0.0.0/0 → Internet Gateway` | `0.0.0.0/0 → NAT Gateway` (or none at all = isolated) |
| Instances get | Public IPs (`map_public_ip_on_launch = true`) | Private IPs only |
| Reachable from internet | Yes (if SG/NACL allow) | **No** |
| Put here | Load balancers, NAT gateways, bastion hosts | App servers, databases, caches, internal services |

Best practice is the **3-tier layout**: ALB in public subnets, app servers in private subnets (outbound through NAT), databases in isolated private subnets, all duplicated across 2–3 AZs. My homework project keeps it to one public subnet to stay simple. It is the "public" half of that design.
