#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n monitoring get deploy,svc"
run_cmd "kubectl -n obs get deploy,svc,pods"

kubectl -n monitoring port-forward svc/grafana 3000:80 >/dev/null 2>&1 &
PF=$!
sleep 4

echo ""
echo "\$ # (exam path is the UI - this is the API equivalent)"
echo "\$ curl -X POST http://localhost:3000/api/datasources -u admin:admin -d '{\"name\":\"PromLab\",...}'"
curl -s -X POST http://localhost:3000/api/datasources \
  -H 'Content-Type: application/json' -u admin:admin \
  -d '{"name":"PromLab","type":"prometheus","url":"http://prom.obs.svc:9090","access":"proxy","isDefault":true}' | python3 -m json.tool

echo ""
echo "\$ curl -X POST http://localhost:3000/api/dashboards/db ... (coral-dashboard with Request Mix panel)"
curl -s -X POST http://localhost:3000/api/dashboards/db \
  -H 'Content-Type: application/json' -u admin:admin \
  -d '{
    "dashboard": {
      "title": "coral-dashboard",
      "panels": [{
        "type": "timeseries",
        "title": "Request Mix",
        "gridPos": {"h": 9, "w": 24, "x": 0, "y": 0},
        "datasource": {"type": "prometheus", "uid": null},
        "targets": [{"expr": "rate(http_requests_total[5m])", "refId": "A"}]
      }],
      "time": {"from": "now-15m", "to": "now"}
    },
    "overwrite": true
  }' | python3 -m json.tool

echo ""
echo "\$ # prove the query returns data (via Grafana datasource proxy would need uid; ask Prometheus directly)"
kubectl -n obs port-forward svc/prom 9091:9090 >/dev/null 2>&1 &
PF2=$!
sleep 3
retry 20 6 'curl -s "http://localhost:9091/api/v1/query" --data-urlencode "query=rate(http_requests_total[5m])" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d[\"data\"][\"result\"] else 1)"' || { echo "no metric data yet"; }
curl -s "http://localhost:9091/api/v1/query" --data-urlencode 'query=rate(http_requests_total[5m])' | python3 -c "
import json, sys
d = json.load(sys.stdin)
for r in d['data']['result'][:4]:
    print(r['metric'], '->', r['value'][1])
"

kill $PF $PF2 2>/dev/null || true
