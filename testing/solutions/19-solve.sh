#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n metrics-portal get deploy,pods"
run_cmd "kubectl -n metrics-portal get events --sort-by=.lastTimestamp | tail -12"
run_cmd "kubectl -n metrics-portal get quota,limitrange,secret,pvc"

cat > "$ROOTDIR/triage.txt" <<'EOF'
1. quota portal-quota caps pods at 1 - blocks metrics-ui pod creation
2. secret metrics-db-auth missing - metrics-db pod in CreateContainerConfigError
3. pvc metrics-ui-data missing - metrics-ui pod would stay Pending
EOF
run_cmd "cat $ROOTDIR/triage.txt"

echo ""
echo "\$ kubectl apply -f portal-quota.yaml   # fix 1: loosen the quota"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: portal-quota
  namespace: metrics-portal
spec:
  hard:
    pods: "4"
EOF

run_cmd "kubectl -n metrics-portal create secret generic metrics-db-auth --from-literal=POSTGRES_PASSWORD='s3cret-p0rtal'"

echo ""
echo "\$ kubectl apply -f metrics-ui-data.yaml   # fix 3: the missing PVC"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: metrics-ui-data
  namespace: metrics-portal
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 256Mi
EOF

# speed up the CreateContainerConfigError pod (legal: pod deletes allowed)
kubectl -n metrics-portal delete pod -l app=metrics-db --ignore-not-found >/dev/null 2>&1 || true

echo "waiting for both deployments (RS retry backoff can take ~1 min)..."
run_cmd "kubectl -n metrics-portal wait --for=condition=available deploy --all --timeout=420s"
run_cmd "kubectl -n metrics-portal get deploy,pods,pvc"
