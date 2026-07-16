#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n edge-web get deploy storefront -o jsonpath='{.spec.template.spec.containers[0].resources}'"
echo ""

run_cmd "kubectl -n edge-web autoscale deployment storefront --name=storefront --cpu-percent=60 --min=2 --max=8"

echo "waiting for the HPA to read metrics..."
retry 30 10 '[ -n "$(kubectl -n edge-web get hpa storefront -o jsonpath="{.status.currentMetrics[?(@.resource.name==\"cpu\")].resource.current.averageUtilization}" 2>/dev/null)" ]' || { echo "HPA never read metrics"; exit 1; }
run_cmd "kubectl -n edge-web get hpa storefront"

echo ""
echo "\$ # generate load with four workers"
for w in 1 2 3 4; do
  kubectl -n edge-web run load-gen-$w --image=busybox:1.36 --restart=Never -- \
    /bin/sh -c "while true; do wget -q -O- http://storefront.edge-web.svc >/dev/null 2>&1; done" 2>/dev/null || true
done

echo "waiting for scale-out (>2 replicas)..."
retry 40 10 '[ "$(kubectl -n edge-web get hpa storefront -o jsonpath="{.status.desiredReplicas}")" -gt 2 ] 2>/dev/null' || { echo "no scale-out"; exit 1; }
run_cmd "kubectl -n edge-web get hpa storefront"
run_cmd "kubectl -n edge-web get pods -l app=storefront --no-headers | wc -l"

run_cmd "kubectl -n edge-web delete pod load-gen-1 load-gen-2 load-gen-3 load-gen-4 --ignore-not-found --now"
