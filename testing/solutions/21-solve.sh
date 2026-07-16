#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

echo "\$ for ns in fleet-1 fleet-2 fleet-3 fleet-4; do kubectl label ns \$ns pod-security.kubernetes.io/warn=baseline pod-security.kubernetes.io/warn-version=latest --overwrite; done"
for ns in fleet-1 fleet-2 fleet-3 fleet-4; do
  kubectl label ns "$ns" \
    pod-security.kubernetes.io/warn=baseline \
    pod-security.kubernetes.io/warn-version=latest --overwrite
done

run_cmd "kubectl get ns --show-labels | grep fleet"

echo ""
echo "\$ # restart deployments and capture PSA warnings"
for ns in fleet-1 fleet-2 fleet-3 fleet-4; do
  echo "=== $ns ==="
  kubectl -n "$ns" rollout restart deploy 2>&1
done

echo ""
echo "\$ # server-side dry-run also reveals the warnings without restarts"
for ns in fleet-1 fleet-2 fleet-3 fleet-4; do
  echo "=== $ns ==="
  kubectl -n "$ns" get deploy -o yaml | kubectl apply --dry-run=server -f - 2>&1 | grep -i "warning" || echo "clean"
done

run_cmd "kubectl label ns fleet-2 secops.acme/needs-hardening=true --overwrite"
run_cmd "kubectl label ns fleet-4 secops.acme/needs-hardening=true --overwrite"
run_cmd "kubectl get ns -l secops.acme/needs-hardening=true"
