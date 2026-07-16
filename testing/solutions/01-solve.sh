#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n squad-nebula get deploy,pods"

echo ""
echo "\$ kubectl apply -f nebula-guards.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: nebula-pod-cap
  namespace: squad-nebula
spec:
  hard:
    pods: "6"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: nebula-cpu-defaults
  namespace: squad-nebula
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
      default:
        cpu: 50m
      max:
        cpu: 250m
EOF

run_cmd "kubectl -n squad-nebula describe quota nebula-pod-cap"
run_cmd "kubectl -n squad-nebula describe limitrange nebula-cpu-defaults"

run_cmd "kubectl -n squad-nebula run default-cpu-pod --image=busybox:1.36 --restart=Never -- sleep 3600"
sleep 3
run_cmd "kubectl -n squad-nebula get pod default-cpu-pod -o jsonpath='{.spec.containers[0].resources}'"
echo ""

echo ""
echo "\$ kubectl apply -f over-max-cpu.yaml   # must FAIL"
cat <<'EOF' | kubectl apply -f - && { echo "!! should have been rejected"; exit 1; } || true
apiVersion: v1
kind: Pod
metadata:
  name: over-max-cpu
  namespace: squad-nebula
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        requests:
          cpu: 300m
        limits:
          cpu: 300m
EOF

run_cmd "kubectl -n squad-nebula get quota"
