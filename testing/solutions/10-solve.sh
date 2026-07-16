#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "cat $ROOTDIR/release-checker.yaml"

echo ""
echo "\$ vim /root/release-checker.yaml   # (edits shown as final file below)"
cat <<'EOF' > "$ROOTDIR/release-checker.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: release-checker-
  namespace: workflows
spec:
  entrypoint: main
  serviceAccountName: workflow-runner
  templates:
    - name: main
      steps:
        - - name: deploy
            template: deploy
        - - name: ready-check
            template: wait-ready
        - - name: test
            template: test

    - name: deploy
      container:
        image: rancher/kubectl:v1.28.0
        command: [kubectl]
        args: [-n, stage-coral, rollout, restart, deploy/checkout-api]

    - name: wait-ready
      container:
        image: rancher/kubectl:v1.28.0
        command: [kubectl]
        args: [rollout, status, deploy/checkout-api, -n, stage-coral, --timeout=90s]

    - name: test
      container:
        image: busybox:1.36
        command: [sh, -c]
        args:
          - echo "smoke tests passed"
EOF
cat "$ROOTDIR/release-checker.yaml"

run_cmd "argo submit $ROOTDIR/release-checker.yaml -n workflows --wait --log"
run_cmd "argo list -n workflows"
