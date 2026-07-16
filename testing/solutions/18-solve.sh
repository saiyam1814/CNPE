#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

echo "waiting for the app to boot (it pip-installs otel packages first)..."
retry 30 5 'kubectl -n trace-lab logs deploy/span-switch --tail=5 2>/dev/null | grep -q "tracing DISABLED"' || true
run_cmd "kubectl -n trace-lab logs deploy/span-switch --tail=3"

run_cmd "kubectl -n trace-lab set env deploy/span-switch TRACING_ENABLED=1 OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector.observability.svc:4318"
run_cmd "kubectl -n trace-lab rollout status deploy/span-switch --timeout=300s"
echo "waiting for the old pod to terminate and the new one to boot..."
retry 30 5 '[ "$(kubectl -n trace-lab get pods -l app=span-switch --no-headers 2>/dev/null | wc -l)" = "1" ]' || true
retry 30 5 'kubectl -n trace-lab logs deploy/span-switch --tail=5 2>/dev/null | grep -q "tracing ENABLED"' || true
run_cmd "kubectl -n trace-lab logs deploy/span-switch --tail=3"

kubectl -n observability port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 &
PF=$!
sleep 4

echo "waiting for span-switch to appear in Jaeger..."
retry 30 6 'curl -s http://localhost:16686/api/services | grep -q span-switch' || { kill $PF; exit 1; }
run_cmd "curl -s http://localhost:16686/api/services"
echo ""

echo "waiting for an error trace..."
retry 30 6 'curl -s "http://localhost:16686/api/traces?service=span-switch&tags=%7B%22error%22%3A%22true%22%7D&limit=5" | grep -q exception.message' || { kill $PF; exit 1; }

echo ""
echo "\$ # extract exception.message from the error span"
curl -s "http://localhost:16686/api/traces?service=span-switch&tags=%7B%22error%22%3A%22true%22%7D&limit=5" | python3 -c "
import json, sys
d = json.load(sys.stdin)
msgs = set()
for t in d.get('data', []):
    for s in t['spans']:
        for lg in s.get('logs', []):
            fields = {f['key']: f['value'] for f in lg['fields']}
            if 'exception.message' in fields:
                msgs.add(fields['exception.message'])
for m in msgs:
    print(m)
"
kill $PF 2>/dev/null || true

echo ""
echo "\$ cat > /root/exception.json"
cat > "$ROOTDIR/exception.json" <<'EOF'
{"key": "exception.message", "type": "string", "value": "connection refused to payment-svc:8080"}
EOF
run_cmd "cat $ROOTDIR/exception.json"
