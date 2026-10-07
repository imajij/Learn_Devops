# Learn_DevOps

DevOps class assignments — **Ajij Uttam**, Enrollment No **24bcs10103**.

Each assignment has its own `README.md` with the commands I ran, the **real output** captured from those runs, screenshots, and an explanation of what the output means.

## Class Assignments

| # | Assignment | Submission link |
|---|---|---|
| 1 | Linux Fundamentals | [`Class_Assignments/Linux_Fundamentals/README.md`](Class_Assignments/Linux_Fundamentals/README.md) |
| 2 | Shell Scripting | [`Class_Assignments/Shell_Scripting/README.md`](Class_Assignments/Shell_Scripting/README.md) |
| 3 | Networking Fundamentals | [`Class_Assignments/Networking_Fundamentals/README.md`](Class_Assignments/Networking_Fundamentals/README.md) |
| 4 | Git & GitHub | [`Class_Assignments/Git-GitHub/README.md`](Class_Assignments/Git-GitHub/README.md) |
| 5 | Docker Fundamentals | _in progress_ |
| 6 | DockerFiles & Images | _in progress_ |
| 7 | Docker Networking & Volumes | _in progress_ |
| 8 | Kubernetes Fundamentals | _in progress_ |
| 9 | Kubernetes Pods, ReplicaSet & Deployment | _in progress_ |
| 10 | Kubernetes Networking & Services | _in progress_ |
| 11 | Kubernetes Ingress, ConfigMaps & Secrets | _in progress_ |
| 12 | Kubernetes Storage, HPA & Probes | _in progress_ |
| 13 | Kubernetes Troubleshooting | _in progress_ |
| 14 | Helm | _in progress_ |
| 15 | CI/CD & GitHub Actions | _in progress_ |
| 16 | Complete CI/CD & DevSecOps | _in progress_ |
| 17 | Terraform & Infrastructure as Code | _in progress_ |
| 18 | Cloud & Terraform in Action | _in progress_ |
| 19 | Monitoring, Observability & GitOps | _in progress_ |

## What each assignment covers

**1. Linux Fundamentals** — soft vs hard links proven with inode numbers and link counts (including a dangling soft link and the refused directory hard link), `adduser` vs `useradd` side by side, and `journalctl` filtering by service, tag, priority and time. Run in an Ubuntu 24.04 container with **systemd as PID 1**, so the journal is real. Plus a practised Linux command cheat sheet.

**2. Shell Scripting** — a system information script using variables, `date`, `hostname`, `whoami`, `df`, `ps`, `read -p`, `mkdir`, `touch` and `>` / `>>` redirection, with the full run and the report file it produced.

**3. Networking Fundamentals** — `hostname`, `whoami`, `ip a`, `hostname -I`, `ip route`, `ping`, `nslookup`, `dig`, `curl`, `ss`, `/etc/hosts`, `tracepath`, `traceroute` and `telnet`, each with output and an explanation. Also a host-vs-container comparison showing why ping/traceroute inside a Colima VM are misleading.

**4. Git & GitHub** — `git commit -m` vs `git commit -a -m`, tested on a modified tracked file and a new untracked file at the same time. Then a cherry-pick of one specific commit out of three from a feature branch, with the graph showing the same change under two hashes.

## Evidence

- **Output** is shown as captured text and as terminal screenshots, including commands that failed and why.
- **Terminal screenshots** are rendered from the captured output of those same commands.
- **Raw transcripts** and the scripts that produced them are committed under each assignment's `lab/` folder, so they can be re-run.

## Environment

| | |
|---|---|
| Host | macOS 26 (Apple Silicon, `arm64`) |
| Docker | `29.5.2` via Colima |
| Git | `2.55.0` |
| Linux environment | Ubuntu 24.04.5 LTS in Docker, with systemd as PID 1 |

Linux-only commands (`adduser`, `useradd`, `journalctl`, `ip`, `ss`, `tracepath`, `traceroute`) were run in the Ubuntu container, because macOS does not provide them. The Dockerfile for that environment is [`Class_Assignments/Linux_Fundamentals/lab/Dockerfile`](Class_Assignments/Linux_Fundamentals/lab/Dockerfile).
