#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n release-bay get deploy,svc"
run_cmd "kubectl -n release-bay get virtualservice media-proxy -o jsonpath='{.spec.http[0].route}'"
echo ""

echo ""
echo "\$ kubectl apply -f media-proxy-rollout.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: media-proxy
  namespace: release-bay
spec:
  replicas: 3
  selector:
    matchLabels:
      app: media-proxy
  strategy:
    canary:
      canaryService: media-proxy-canary
      stableService: media-proxy-stable
      trafficRouting:
        istio:
          virtualService:
            name: media-proxy
            routes: [primary]
      steps:
        - setWeight: 20
        - pause: { duration: 30s }
        - setWeight: 40
        - pause: { duration: 30s }
        - setWeight: 100
  template:
    metadata:
      labels:
        app: media-proxy
    spec:
      containers:
        - name: media-proxy
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

echo "waiting for rollout Healthy (rev 1)..."
retry 40 5 '[ "$(kubectl -n release-bay get rollout media-proxy -o jsonpath="{.status.phase}")" = "Healthy" ]' || exit 1
run_cmd "kubectl argo rollouts get rollout media-proxy -n release-bay"

run_cmd "kubectl argo rollouts set image media-proxy media-proxy=nginx:1.26 -n release-bay"

echo "watching weights during the canary..."
for i in 1 2 3; do
  sleep 15
  echo ""
  echo "\$ kubectl -n release-bay get virtualservice media-proxy -o jsonpath='{.spec.http[0].route}'   # t+$((i*15))s"
  kubectl -n release-bay get virtualservice media-proxy -o jsonpath='{.spec.http[0].route}'
  echo ""
done

echo "waiting for full promotion..."
retry 40 6 '[ "$(kubectl -n release-bay get rollout media-proxy -o jsonpath="{.status.phase}")" = "Healthy" ] && [ "$(kubectl -n release-bay get rollout media-proxy -o jsonpath="{.status.currentPodHash}")" = "$(kubectl -n release-bay get rollout media-proxy -o jsonpath="{.status.stableRS}")" ] && [ "$(kubectl -n release-bay get rollout media-proxy -o jsonpath="{.spec.template.spec.containers[0].image}")" = "nginx:1.26" ]' || exit 1

run_cmd "kubectl argo rollouts get rollout media-proxy -n release-bay"
run_cmd "kubectl -n release-bay logs traffic-gen --tail=8 | sort | uniq -c || true"
run_cmd "kubectl -n release-bay scale deploy media-proxy --replicas=0"
