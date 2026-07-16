#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n ci-otter get pipeline build-ship -o yaml | grep -A22 'tasks:' | head -26"

echo ""
echo "\$ kubectl apply -f scan-image-task.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: scan-image
  namespace: ci-otter
spec:
  params:
    - name: image
      type: string
  steps:
    - name: trivy
      image: aquasec/trivy:0.58.1
      script: |
        #!/bin/sh
        set -eu
        echo "scanning $(params.image) for CRITICAL CVEs..."
        trivy image --exit-code 1 --severity CRITICAL --scanners vuln "$(params.image)"
EOF

echo ""
echo "\$ kubectl apply -f build-ship-pipeline.yaml   # scan wired between image and deploy"
cat <<'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-ship
  namespace: ci-otter
spec:
  params:
    - name: image
      type: string
  tasks:
    - name: image
      taskRef:
        name: resolve-image
      params:
        - name: image
          value: $(params.image)
    - name: scan
      taskRef:
        name: scan-image
      runAfter: [image]
      params:
        - name: image
          value: $(tasks.image.results.image-url)
    - name: deploy
      taskRef:
        name: deploy-image
      runAfter: [scan]
      params:
        - name: image
          value: $(tasks.image.results.image-url)
EOF

echo ""
echo "\$ tkn pipeline start build-ship -n ci-otter -p image=nginx:1.16 --showlog   # must FAIL"
tkn pipeline start build-ship -n ci-otter -p image=nginx:1.16 --showlog 2>&1 | tail -25 || true

echo "confirming the vulnerable run failed and nothing deployed..."
retry 40 8 'kubectl -n ci-otter get pipelinerun -o json | python3 -c "
import json,sys
prs=json.load(sys.stdin)[\"items\"]
ok=False
for pr in prs:
    ps={p[\"name\"]:p.get(\"value\") for p in pr.get(\"spec\",{}).get(\"params\",[])}
    if ps.get(\"image\")==\"nginx:1.16\":
        for c in pr.get(\"status\",{}).get(\"conditions\",[]):
            if c.get(\"type\")==\"Succeeded\" and c.get(\"status\")==\"False\": ok=True
sys.exit(0 if ok else 1)"' || exit 1
run_cmd_expect_fail "kubectl -n ci-otter get deploy shipped"

echo ""
echo "\$ tkn pipeline start build-ship -n ci-otter -p image=gcr.io/distroless/static:nonroot --showlog   # must PASS"
tkn pipeline start build-ship -n ci-otter -p image=gcr.io/distroless/static:nonroot --showlog 2>&1 | tail -20

echo "confirming the clean run succeeded and deployed..."
retry 40 8 'kubectl -n ci-otter get pipelinerun -o json | python3 -c "
import json,sys
prs=json.load(sys.stdin)[\"items\"]
ok=False
for pr in prs:
    ps={p[\"name\"]:p.get(\"value\") for p in pr.get(\"spec\",{}).get(\"params\",[])}
    if ps.get(\"image\")==\"gcr.io/distroless/static:nonroot\":
        for c in pr.get(\"status\",{}).get(\"conditions\",[]):
            if c.get(\"type\")==\"Succeeded\" and c.get(\"status\")==\"True\": ok=True
sys.exit(0 if ok else 1)"' || exit 1

run_cmd "tkn pipelinerun list -n ci-otter"
run_cmd "kubectl -n ci-otter get deploy shipped -o jsonpath='{.spec.template.spec.containers[0].image}'"
echo ""
