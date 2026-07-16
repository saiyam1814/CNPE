#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n storage-lab get pods"
run_cmd "kubectl -n storage-lab get deploy -o yaml | grep -B2 -A3 claimName"
run_cmd "kubectl get storageclass"
run_cmd "touch $ROOTDIR/investigated"

echo ""
echo "\$ kubectl apply -f pvcs.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pg-storage
  namespace: storage-lab
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: fast-iops
  resources:
    requests:
      storage: 512Mi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cdn-cache
  namespace: storage-lab
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: standard
  resources:
    requests:
      storage: 512Mi
EOF

run_cmd "kubectl -n storage-lab wait --for=condition=available deploy/pg deploy/cdn --timeout=300s"
run_cmd "kubectl -n storage-lab get pvc,pods"
