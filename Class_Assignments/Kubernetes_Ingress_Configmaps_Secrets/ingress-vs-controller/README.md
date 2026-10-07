# Ingress vs Ingress Controller

**Name:** Ajij Uttam  **Enrollment No:** 24bcs10103

Examples refer to what I ran on my minikube cluster in [the main README, Task 3](../README.md#task-3--ingress).

## What is Ingress?

An **Ingress** is a Kubernetes **API object** (`networking.k8s.io/v1`, kind `Ingress`). It holds **HTTP(S) routing rules** for traffic coming into the cluster: *"requests for host X and path Y go to Service Z on port P"*, plus optional TLS settings. It is only configuration. By itself it does nothing, opens no port and runs no process.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yatri-ingress
spec:
  ingressClassName: nginx          # which controller should implement this
  rules:
    - host: yatri.local
      http:
        paths:
          - path: /api(/|$)(.*)     # → backend
            pathType: ImplementationSpecific
            backend: { service: { name: yatri-backend-service, port: { number: 80 } } }
          - path: /                 # → frontend
            pathType: Prefix
            backend: { service: { name: yatri-frontend-service, port: { number: 80 } } }
```

## What is an Ingress Controller?

An **Ingress Controller** is a **running application**: a reverse proxy/load balancer plus a control loop, deployed as pods in the cluster. It **watches the API server** for Ingress objects (and the Services/EndpointSlices they point to), **turns them into its own proxy configuration**, and **actually receives and forwards the traffic**.

On my cluster: `minikube addons enable ingress` deployed **ingress-nginx v1.15.1** as Deployment `ingress-nginx-controller` in namespace `ingress-nginx`, exposed by a NodePort Service (80→31884, 443→32623), with IngressClass `nginx`. Inside its pod, my two Ingress objects had become `server_name "yatri.local"`, `server_name "api.yatri.local"` and `location ~* "^/api(/|$)(.*)"` blocks in `/etc/nginx/nginx.conf`.

## Difference between them

| | Ingress | Ingress Controller |
|---|---|---|
| What it is | A **resource** (YAML stored in etcd) | **Software** (pods running a proxy) |
| Role | *Declares* routing rules: the "what" | *Implements* the rules and carries the traffic: the "how" |
| Built into Kubernetes? | Yes, the API type ships with Kubernetes | **No**, you install one (kube-controller-manager does not include one) |
| How many | Many, written by app teams, one or more per app/namespace | Usually one or a few per cluster, run by the platform team |
| Without the other | Rules exist but nobody acts on them: no ADDRESS, no traffic | Proxy runs but has no rules: everything gets its default 404 |
| Selected by | `spec.ingressClassName` → an `IngressClass` → a controller | Watches the IngressClass it owns (`k8s.io/ingress-nginx`) |
| Analogy | The **routing table / config file** | The **router / nginx process** that reads it |

## Why both are required

Kubernetes splits **intent** from **implementation**, the same way a Deployment (intent) needs the Deployment controller (implementation):

1. **The Ingress** gives app teams a portable, cloud-neutral way to say "expose my Service at this host/path with this TLS cert", without touching load-balancer config.
2. **The Controller** does the real work: it listens on ports 80/443, terminates TLS, matches Host/path, load-balances straight to pod IPs, and handles retries, timeouts and rewrites. Different controllers can implement the same Ingress (nginx, Traefik, HAProxy, cloud LBs).
3. **One entry point for many services.** One controller (behind one LoadBalancer/IP) can serve dozens of apps by host and path. Without it, every app would need its own LoadBalancer Service, with its own cloud LB and public IP, which costs more and is harder to manage.

What I saw on my cluster confirms the split. Once the addon was enabled, the controller **filled in the ADDRESS** (`192.168.49.2`), generated nginx config, and its access log showed each request with the upstream **pod** it chose. A `Host` that matched no rule (`unknown.local`) got the controller's own **404**, which shows the controller handles all traffic and the Ingress only supplies the rules.

## Examples

**Ingress controllers:**
- **ingress-nginx** (Kubernetes community, used here) and **NGINX Ingress Controller** (F5/NGINX Inc., a different project)
- **Traefik** (default in k3s), **HAProxy Ingress**, **Contour** (Envoy), **Kong**, **Istio ingress gateway**
- Cloud: **AWS Load Balancer Controller** (Ingress → an ALB), **GKE Ingress** (Google Cloud HTTP(S) LB), **Azure Application Gateway Ingress Controller**

**Ingress use cases:**
- Path routing: `shop.com/api` → API Service, `shop.com/` → frontend (my `yatri-ingress`)
- Host routing: `api.shop.com` → API, `admin.shop.com` → admin UI (my `yatri-hosts`)
- TLS termination with a cert from a Secret (`spec.tls`), often issued automatically by cert-manager
- Canary by weight with ingress-nginx annotations (`nginx.ingress.kubernetes.io/canary-weight: "10"`)

**Related:** the newer **Gateway API** (`Gateway`, `HTTPRoute`) uses the same split but goes further: infrastructure teams own the `Gateway` (like the controller config) and app teams own the `HTTPRoute` (like the Ingress rules).
