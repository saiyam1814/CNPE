#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl get deploy -A | grep -E 'NAMESPACE|alpha|beta|gamma'"

echo "waiting for opencost allocation data..."
kubectl -n opencost port-forward svc/opencost 9003:9003 >/dev/null 2>&1 &
PF=$!
sleep 4
retry 30 10 'curl -s "http://localhost:9003/allocation/compute?window=10m&aggregate=namespace" | grep -q "alpha-svc"' || { echo "no allocation data"; kill $PF; exit 1; }

echo ""
echo "\$ curl -s 'http://localhost:9003/allocation/compute?window=10m&aggregate=namespace' | (parse totals)"
curl -s "http://localhost:9003/allocation/compute?window=10m&aggregate=namespace" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sets = d.get('data', [])
rows = {}
for s in sets:
    for name, a in (s or {}).items():
        if name.endswith('-svc'):
            rows[name] = rows.get(name, 0) + a.get('totalCost', 0)
for name, cost in sorted(rows.items(), key=lambda kv: kv[1]):
    print(f'{name:12s} totalCost={cost:.6f}')
"
kill $PF 2>/dev/null || true

# kubectl cost plugin (best effort - flags depend on plugin version)
if command -v kubectl-cost >/dev/null 2>&1; then
  echo ""
  echo "\$ kubectl cost namespace --service-name opencost --service-port 9003 -N opencost --allocation-path /allocation/compute --window 10m"
  kubectl cost namespace --service-name opencost --service-port 9003 -N opencost --allocation-path /allocation/compute --window 10m 2>&1 | head -14 || echo "(kubectl cost failed - allocation API output above is authoritative)"
fi

run_cmd "echo api-alpha > $ROOTDIR/cheapest.txt"
run_cmd "echo api-gamma > $ROOTDIR/expensive.txt"

run_cmd "kubectl -n alpha-svc scale deploy api-alpha --replicas=\$(( \$(kubectl -n alpha-svc get deploy api-alpha -o jsonpath='{.spec.replicas}') + 2 ))"
run_cmd "kubectl -n gamma-svc scale deploy api-gamma --replicas=2"
run_cmd "kubectl -n alpha-svc label deploy api-alpha cost.platform.io/adjusted=yes"
run_cmd "kubectl -n gamma-svc label deploy api-gamma cost.platform.io/adjusted=yes"
run_cmd "kubectl get deploy -A -l cost.platform.io/adjusted=yes"
