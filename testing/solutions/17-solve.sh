#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n monitoring get prometheus main -o jsonpath='{.spec.ruleSelector}'"
echo ""

echo ""
echo "\$ kubectl apply -f prometheusrule.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: frontend-slo
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: frontend.slo
      rules:
        - alert: FrontendHighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
              /
            sum(rate(http_requests_total[5m]))
              > 0.05
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Frontend 5xx ratio above 5%"
            description: "Error ratio is {{ $value | humanizePercentage }}"
EOF

run_cmd "kubectl -n monitoring get prometheusrule"

kubectl -n monitoring port-forward svc/prometheus-main 9090:9090 >/dev/null 2>&1 &
PF=$!
sleep 4

echo "waiting for the rule to appear in Prometheus..."
retry 30 6 'curl -s http://localhost:9090/api/v1/rules | grep -q FrontendHighErrorRate' || { kill $PF; exit 1; }

echo ""
echo "\$ curl -s http://localhost:9090/api/v1/rules | (show rule states)"
curl -s http://localhost:9090/api/v1/rules | python3 -c "
import json, sys
d = json.load(sys.stdin)
for g in d['data']['groups']:
    for r in g['rules']:
        print(f\"{r.get('name')}  state={r.get('state', '-')}\")"

echo ""
echo "\$ # live error ratio (the lab generates ~8% errors)"
retry 20 6 'curl -s "http://localhost:9090/api/v1/query" --data-urlencode "query=sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))" | python3 -c "import json,sys; r=json.load(sys.stdin)[\"data\"][\"result\"]; sys.exit(0 if r else 1)"'
curl -s "http://localhost:9090/api/v1/query" --data-urlencode 'query=sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))' | python3 -c "
import json, sys
r = json.load(sys.stdin)['data']['result']
print('error ratio:', r[0]['value'][1] if r else 'no data')"

echo "waiting for the alert to reach pending/firing..."
retry 40 10 'curl -s http://localhost:9090/api/v1/rules | python3 -c "
import json,sys
d=json.load(sys.stdin)
ok=False
for g in d[\"data\"][\"groups\"]:
    for r in g[\"rules\"]:
        if r.get(\"name\")==\"FrontendHighErrorRate\" and r.get(\"state\") in (\"pending\",\"firing\"): ok=True
sys.exit(0 if ok else 1)"' || { kill $PF; exit 1; }

echo ""
echo "\$ curl -s http://localhost:9090/api/v1/alerts"
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool | head -30

kill $PF 2>/dev/null || true
