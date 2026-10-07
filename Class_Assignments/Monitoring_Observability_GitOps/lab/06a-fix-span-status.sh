#!/usr/bin/env bash
# Bug fix found in Jaeger: healthy spans were drawn with an error icon because the app sent an
# attribute error="false". Now the app only sets the OTLP span status (1=OK, 2=ERROR). Rebuild + restart.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 06a-fix-span-status
r "docker build -q -t shop-app:1.0 app/ 2>/dev/null"
r "minikube -p obs image load --overwrite=true shop-app:1.0"
r "kubectl --context obs -n shop rollout restart deploy/shop deploy/payments deploy/loadgen"
r "kubectl --context obs -n shop rollout status deploy/shop --timeout=120s"
r "kubectl --context obs -n shop rollout status deploy/payments --timeout=120s"
r "kubectl --context obs -n shop get pods"
