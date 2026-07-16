#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl get constrainttemplate forbidfloatingtag -o jsonpath='{.spec.crd.spec.names.kind}'"
echo ""

echo ""
echo "\$ kubectl apply -f forbid-floating-tags.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: ForbidFloatingTag
metadata:
  name: forbid-floating-tags
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "DaemonSet", "StatefulSet", "ReplicaSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
      - apiGroups: [""]
        kinds: ["Pod"]
EOF

run_cmd "kubectl get forbidfloatingtag forbid-floating-tags"
echo "giving the webhook time to sync the constraint..."
sleep 20

run_cmd_expect_fail "kubectl -n tag-lab create deploy floating-latest --image=busybox:latest -- sleep 3600"
run_cmd_expect_fail "kubectl -n tag-lab create deploy missing-tag --image=busybox -- sleep 3600"
run_cmd "kubectl -n tag-lab create deploy pinned-ok --image=busybox:1.36.1 -- sleep 3600"
run_cmd "kubectl -n tag-lab get deploy"
