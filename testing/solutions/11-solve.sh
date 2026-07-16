#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n pipeline-lab get pipeline,task"

echo ""
echo "\$ kubectl apply -f kubectl-apply-task.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: kubectl-apply
  namespace: pipeline-lab
spec:
  params:
    - name: manifest
      type: string
  steps:
    - name: apply
      image: rancher/kubectl:v1.28.0
      script: |
        #!/bin/sh
        set -eu
        printf '%s\n' "$(params.manifest)" > /tmp/out.yaml
        kubectl apply -f /tmp/out.yaml
EOF

echo ""
echo "\$ kubectl apply -f compile-release-pipeline.yaml   # adds the apply task"
cat <<'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: compile-release
  namespace: pipeline-lab
spec:
  tasks:
    - name: build
      taskRef:
        name: build
    - name: package
      taskRef:
        name: package
    - name: apply
      taskRef:
        name: kubectl-apply
      runAfter: [build, package]
      params:
        - name: manifest
          value: $(tasks.package.results.manifest)
EOF

run_cmd "tkn pipeline start compile-release -n pipeline-lab --showlog"
sleep 5
run_cmd "tkn pipelinerun list -n pipeline-lab"

echo "waiting for pipelinerun success..."
retry 40 6 'kubectl -n pipeline-lab get pipelinerun -o jsonpath="{range .items[*]}{.status.conditions[?(@.type==\"Succeeded\")].status}{\"\\n\"}{end}" | grep -q True' || exit 1

run_cmd "kubectl -n pipeline-lab get deploy compiled-web"
run_cmd "kubectl -n pipeline-lab wait --for=condition=available deploy/compiled-web --timeout=120s"
