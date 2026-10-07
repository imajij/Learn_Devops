# Learn_DevOps

DevOps class assignments — **Ajij Uttam**, Enrollment No **24bcs10103**.

All the homework assignments. Each one has its own `README.md` with the commands I ran, the **real output** captured from those runs, screenshots, and an explanation of what the output means.

## Class Assignments

| # | Assignment | Submission link |
|---|---|---|
| 1 | Linux Fundamentals | [`Class_Assignments/Linux_Fundamentals/README.md`](Class_Assignments/Linux_Fundamentals/README.md) |
| 2 | Shell Scripting | [`Class_Assignments/Shell_Scripting/README.md`](Class_Assignments/Shell_Scripting/README.md) |
| 3 | Networking Fundamentals | [`Class_Assignments/Networking_Fundamentals/README.md`](Class_Assignments/Networking_Fundamentals/README.md) |
| 4 | Git & GitHub | [`Class_Assignments/Git-GitHub/README.md`](Class_Assignments/Git-GitHub/README.md) |
| 5 | Docker Fundamentals | [`Class_Assignments/Docker_Fundamental/README.md`](Class_Assignments/Docker_Fundamental/README.md) |
| 6 | DockerFiles & Images | [`Class_Assignments/DockerFiles_&_Images/README.md`](Class_Assignments/DockerFiles_&_Images/README.md) |
| 7 | Docker Networking & Volumes | [`Class_Assignments/Docker_Network/README.md`](Class_Assignments/Docker_Network/README.md) |
| 8 | Kubernetes Fundamentals | [`Class_Assignments/Kubernetes_Fundamentals/README.md`](Class_Assignments/Kubernetes_Fundamentals/README.md) |
| 9 | Kubernetes Pods, ReplicaSet & Deployment | [`Class_Assignments/Kubernetes_Pods_Rs_Deployment/README.md`](Class_Assignments/Kubernetes_Pods_Rs_Deployment/README.md) |
| 10 | Kubernetes Networking & Services | [`Class_Assignments/Kubernetes_Networking_and_Services/README.md`](Class_Assignments/Kubernetes_Networking_and_Services/README.md) |
| 11 | Kubernetes Ingress, ConfigMaps & Secrets | [`Class_Assignments/Kubernetes_Ingress_Configmaps_Secrets/README.md`](Class_Assignments/Kubernetes_Ingress_Configmaps_Secrets/README.md) |
| 12 | Kubernetes Storage, HPA & Probes | [`Class_Assignments/Kubernetes_Storage_HPA_Probes/README.md`](Class_Assignments/Kubernetes_Storage_HPA_Probes/README.md) |
| 13 | Kubernetes Troubleshooting | [`Class_Assignments/Kubernetes_Troubleshooting/README.md`](Class_Assignments/Kubernetes_Troubleshooting/README.md) |
| 14 | Helm | [`Class_Assignments/Helm/README.md`](Class_Assignments/Helm/README.md) |
| 15 | CI/CD & GitHub Actions | [`Class_Assignments/CICD_GitHub_Actions/README.md`](Class_Assignments/CICD_GitHub_Actions/README.md) |
| 16 | Complete CI/CD & DevSecOps | [`Class_Assignments/DevSecOps/README.md`](Class_Assignments/DevSecOps/README.md) |
| 17 | Terraform & Infrastructure as Code | [`Class_Assignments/Terraform/README.md`](Class_Assignments/Terraform/README.md) |
| 18 | Cloud & Terraform in Action | [`Class_Assignments/Cloud_and_Terraform_in_Action/README.md`](Class_Assignments/Cloud_and_Terraform_in_Action/README.md) |
| 19 | Monitoring, Observability & GitOps | [`Class_Assignments/Monitoring_Observability_GitOps/README.md`](Class_Assignments/Monitoring_Observability_GitOps/README.md) |
| 20 | Final DevOps Project & Troubleshooting | _in progress_ |

## What each assignment covers

**1. Linux Fundamentals** — soft vs hard links proven with inode numbers and link counts (including a dangling soft link and the refused directory hard link), `adduser` vs `useradd` side by side, and `journalctl` filtering by service, tag, priority and time. Run in an Ubuntu 24.04 container with **systemd as PID 1**, so the journal is real. Plus a practised Linux command cheat sheet.

**2. Shell Scripting** — a system information script using variables, `date`, `hostname`, `whoami`, `df`, `ps`, `read -p`, `mkdir`, `touch` and `>` / `>>` redirection, with the full run and the report file it produced.

**3. Networking Fundamentals** — `hostname`, `whoami`, `ip a`, `hostname -I`, `ip route`, `ping`, `nslookup`, `dig`, `curl`, `ss`, `/etc/hosts`, `tracepath`, `traceroute` and `telnet`, each with output and an explanation. Also a host-vs-container comparison showing why ping/traceroute inside a Colima VM are misleading.

**4. Git & GitHub** — `git commit -m` vs `git commit -a -m`, tested on a modified tracked file and a new untracked file at the same time. Then a cherry-pick of one specific commit out of three from a feature branch, with the graph showing the same change under two hashes.

**5. Docker Fundamentals** — six Hello World web apps (Node.js, Python, Java, Apache, React, Nginx), each in its own folder with a Dockerfile, built, run on ports **8101–8106** and checked in the browser.

**6. DockerFiles & Images** — the instructor's multi-stage Dockerfile serving *Hello World from Docker multi-stage build* on **port 8080**, plus three multi-stage apps (Node, Python, Java). Measured against single-stage builds: **1.65 GB → 249 MB** for the class app.

**7. Docker Networking & Volumes** — frontend, backend and MySQL across three networks, with the backend on two and both connectivity and isolation proven. Also Apache on the host network, a bind mount updating live with no restart, and a real overlay network in swarm mode.

**8. Kubernetes Fundamentals** — minikube setup and cluster status, the control-plane components running live in `kube-system`, and the Kubernetes Basics tutorial: deploy, expose, scale to **4** replicas, rolling update, and a rollback after a bad image.

**9. Kubernetes Pods, ReplicaSet & Deployment** — all **4** rollout strategies measured with live traffic: rolling update, blue-green (**10/10** requests switched), canary (**~10%** at 9:1), and recreate (about **5 s** of downtime). Also **12** pod-lifecycle YAMLs applied and explained.

**10. Kubernetes Networking & Services** — all **5** Service types (ClusterIP, NodePort, LoadBalancer via `minikube tunnel`, ExternalName, headless) with connectivity tests. Also object comparisons, an FQDN guide with real `nslookup` output, and CoreDNS with the cluster's real Corefile and a break-and-fix DNS demo.

**11. Kubernetes Ingress, ConfigMaps & Secrets** — ConfigMaps and Secrets as env vars and as files; after an update the mounted file changed in **3 s** while the env var did not. Also host- and path-based Ingress routing through ingress-nginx, Ingress vs Ingress Controller, and a three-fault troubleshooting exercise (503 → 502 → 200).

**12. Kubernetes Storage, HPA & Probes** — `emptyDir`, `hostPath`, static PV/PVC and dynamic provisioning, each shown keeping or losing data. An HPA scaling **1 → 3** under load and back to **1** after the stabilization window. Liveness, readiness and startup probes failing and recovering, and the probes mini project.

**13. Kubernetes Troubleshooting** — every core `kubectl` debugging command, then **9** issues broken on purpose and fixed: CrashLoopBackOff, ImagePullBackOff, ErrImagePull, Pending, ContainerCreating, Service, DNS, pod networking and config. Each has before/after output, plus the mini project.

**14. Helm** — every core Helm command. A rollback workflow where a bad image tag upgrade is rolled back, and a Notes chart installed with dev values, upgraded to prod values, broken, and rolled back.

**15. CI/CD & GitHub Actions** — a Flask API with **11** tests and a **4**-job workflow: test → build/artifacts → Docker build & push → deploy with a smoke test. Runs shown: a green push, a failing test stopping the pipeline, and a pull request where CD is skipped. All run locally with `act`.

**16. Complete CI/CD & DevSecOps** — a **10**-job pipeline: Build → Test → SAST (Bandit) → SCA (pip-audit) → Secret Scan (Gitleaks) → Docker Build → Image Scan (Trivy) → Security Gate → Push → Deploy to Kubernetes. The gate blocked the first run on real findings; after the fixes the second run passed and deployed **2/2** pods.

**17. Terraform & IaC** — an S3 bucket (versioning, encryption, public access block) through `init → fmt → validate → plan → apply → show → output → destroy`, plus drift caught by a second plan. Research READMEs on **IAM, EC2, S3, VPC, DynamoDB & RDS**.

**18. Cloud & Terraform in Action** — VPC, subnet, internet gateway, route table, security group, EC2 with an IAM role, and S3 from one project: **14** resources, the dependency graph, state, plan/apply/destroy, and an architecture diagram.

**19. Monitoring, Observability & GitOps** — Prometheus, Grafana and **4** alert rules firing during a simulated incident. Metrics, JSON logs and Jaeger traces linked by `trace_id`. Argo CD syncing from Git, undoing a manual change in about **3 s**, pruning, and rolling back with `git revert`.

## Evidence

- **Output** is shown as captured text and as terminal screenshots, including commands that failed and why.
- **Terminal screenshots** are rendered from the captured output of those same commands; **browser screenshots** are real captures of pages served by my running apps, Grafana, Argo CD, etc.
- **Raw transcripts** and the scripts that produced them are committed under each assignment's `lab/` folder, so they can be re-run.

## Environment

| | |
|---|---|
| Host | macOS 26 (Apple Silicon, `arm64`) |
| Docker | `29.5.2` via Colima |
| Git | `2.55.0` |
| Linux environment | Ubuntu 24.04.5 LTS in Docker, with systemd as PID 1 |
| Kubernetes | minikube `v1.39.0`, Kubernetes `v1.37.0`; kind `v0.33.0` (DevSecOps deploy target) |
| Helm | `v4.3.0` |
| CI/CD | GitHub Actions workflows run locally with `act` `v0.2.89` |
| AWS | Terraform `v1.16.4` against LocalStack `4.0` (an AWS emulator in Docker) |
| Monitoring / GitOps | kube-prometheus-stack, Jaeger `v2.22.0`, Argo CD `v3.5.4` |

Linux-only commands (`adduser`, `useradd`, `journalctl`, `ip`, `ss`, `tracepath`, `traceroute`) were run in the Ubuntu container, because macOS does not provide them. The Dockerfile for that environment is [`Class_Assignments/Linux_Fundamentals/lab/Dockerfile`](Class_Assignments/Linux_Fundamentals/lab/Dockerfile).
