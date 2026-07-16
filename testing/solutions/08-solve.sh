#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n shop-core get deploy,svc,pods"

echo ""
echo "\$ kubectl apply -f bluegreen-rollout.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: catalog
  namespace: shop-core
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  strategy:
    blueGreen:
      activeService: catalog-active
      previewService: catalog-preview
      autoPromotionEnabled: false
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
        - name: catalog
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

echo "waiting for rollout Healthy..."
retry 40 5 '[ "$(kubectl -n shop-core get rollout catalog -o jsonpath="{.status.phase}")" = "Healthy" ]' || exit 1
run_cmd "kubectl argo rollouts get rollout catalog -n shop-core"

run_cmd "kubectl argo rollouts set image catalog catalog=nginx:1.26 -n shop-core"

echo "waiting for Paused (preview up, human gate)..."
retry 40 5 '[ "$(kubectl -n shop-core get rollout catalog -o jsonpath="{.status.phase}")" = "Paused" ]' || exit 1
run_cmd "kubectl argo rollouts get rollout catalog -n shop-core"

run_cmd "kubectl -n shop-core run qa --rm -i --restart=Never --image=curlimages/curl:8.9.1 -- sh -c 'echo -n \"active:  \"; curl -sI catalog-active.shop-core.svc | grep -i ^server; echo -n \"preview: \"; curl -sI catalog-preview.shop-core.svc | grep -i ^server'"

run_cmd "kubectl argo rollouts promote catalog -n shop-core"

echo "waiting for promotion to finish..."
retry 40 5 '[ "$(kubectl -n shop-core get rollout catalog -o jsonpath="{.status.phase}")" = "Healthy" ] && [ "$(kubectl -n shop-core get rollout catalog -o jsonpath="{.status.currentPodHash}")" = "$(kubectl -n shop-core get rollout catalog -o jsonpath="{.status.stableRS}")" ]' || exit 1

run_cmd "kubectl argo rollouts get rollout catalog -n shop-core"
run_cmd "kubectl -n shop-core scale deploy catalog --replicas=0"
run_cmd "kubectl -n shop-core get rollout,deploy"
