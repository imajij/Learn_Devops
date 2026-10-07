# shop-gitops

Desired state for the `gitops-demo` namespace. Argo CD watches the `app/` folder of this repo
(served from the in-cluster git server at http://git-server.git.svc:3000/shop-gitops.git).
Change the cluster by committing here, never with kubectl.
