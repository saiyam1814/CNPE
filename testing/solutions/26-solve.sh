#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n release-bay get deploy,svc,virtualservice"

echo ""
echo "\$ kubectl apply -f media-proxy-canary.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: media-proxy
  namespace: release-bay
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: media-proxy
  progressDeadlineSeconds: 300
  service:
    port: 80
  analysis:
    interval: 20s
    threshold: 3
    maxWeight: 100
    stepWeight: 20
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
EOF

echo "waiting for Flagger to initialize the canary..."
retry 40 8 '[ "$(kubectl -n release-bay get canary media-proxy -o jsonpath="{.status.phase}" 2>/dev/null)" = "Initialized" ]' || {
  kubectl -n release-bay describe canary media-proxy | tail -15; exit 1; }

run_cmd "kubectl -n release-bay get canary media-proxy"
run_cmd "kubectl -n release-bay get deploy,svc,virtualservice"

run_cmd "kubectl -n release-bay set image deploy/media-proxy media-proxy=nginx:1.26"

echo "watching the canary progress (weights on the VirtualService)..."
for i in 1 2 3 4; do
  sleep 25
  echo ""
  echo "\$ kubectl -n release-bay get virtualservice media-proxy -o jsonpath='{.spec.http[0].route}'   # t+$((i*25))s"
  kubectl -n release-bay get virtualservice media-proxy -o jsonpath='{.spec.http[0].route}' || true
  echo ""
  kubectl -n release-bay get canary media-proxy --no-headers || true
done

echo "waiting for promotion (Succeeded)..."
retry 40 10 '[ "$(kubectl -n release-bay get canary media-proxy -o jsonpath="{.status.phase}" 2>/dev/null)" = "Succeeded" ]' || {
  kubectl -n release-bay describe canary media-proxy | tail -25; exit 1; }

run_cmd "kubectl -n release-bay get canary media-proxy"
run_cmd "kubectl -n release-bay get events --field-selector involvedObject.name=media-proxy --sort-by=.lastTimestamp | tail -12"
run_cmd "kubectl -n release-bay get deploy media-proxy-primary -o jsonpath='{.spec.template.spec.containers[0].image}'"
echo ""
