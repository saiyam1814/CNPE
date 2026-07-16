#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "tkn pipeline start build-ship -n ci-otter -p gitrevision=manual-test --showlog"

echo ""
echo "\$ kubectl apply -f triggers.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: build-ship-tt
  namespace: ci-otter
spec:
  params:
    - name: gitrevision
      default: main
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: build-ship-
      spec:
        pipelineRef:
          name: build-ship
        params:
          - name: gitrevision
            value: $(tt.params.gitrevision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: build-ship-tb
  namespace: ci-otter
spec:
  params:
    - name: gitrevision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: build-ship-el
  namespace: ci-otter
spec:
  serviceAccountName: tekton-triggers
  triggers:
    - name: on-push
      bindings:
        - ref: build-ship-tb
      template:
        ref: build-ship-tt
EOF

run_cmd "kubectl -n ci-otter wait --for=condition=available deploy/el-build-ship-el --timeout=180s"
run_cmd "kubectl -n ci-otter get deploy,svc"

kubectl -n ci-otter port-forward svc/el-build-ship-el 8080:8080 >/dev/null 2>&1 &
PF=$!
sleep 4

echo ""
echo "\$ curl -s -X POST http://127.0.0.1:8080 -H 'Content-Type: application/json' -d '{\"after\": \"4f2c1ab\"}'"
curl -s -X POST http://127.0.0.1:8080 -H 'Content-Type: application/json' -d '{"after": "4f2c1ab"}' | python3 -m json.tool
kill $PF 2>/dev/null || true

echo "waiting for the webhook-spawned run to succeed..."
retry 40 6 'kubectl -n ci-otter get pipelinerun -o json | python3 -c "
import json,sys
prs=json.load(sys.stdin)[\"items\"]
ok=False
for pr in prs:
    ps={p[\"name\"]:p.get(\"value\") for p in pr.get(\"spec\",{}).get(\"params\",[])}
    if ps.get(\"gitrevision\")==\"4f2c1ab\":
        for c in pr.get(\"status\",{}).get(\"conditions\",[]):
            if c.get(\"type\")==\"Succeeded\" and c.get(\"status\")==\"True\": ok=True
sys.exit(0 if ok else 1)"' || exit 1

run_cmd "tkn pipelinerun list -n ci-otter"
run_cmd "tkn pipelinerun logs --last -n ci-otter"
