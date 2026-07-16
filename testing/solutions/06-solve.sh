#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n argocd get pods"

echo ""
echo "\$ kubectl apply -f podinfo-application.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-ui
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/stefanprodan/podinfo
    targetRevision: master
    path: charts/podinfo
    helm:
      values: |
        replicaCount: 2
        service:
          type: ClusterIP
        ui:
          color: "#336699"
  destination:
    server: https://kubernetes.default.svc
    namespace: apps-ui
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "waiting for Synced + Healthy..."
retry 60 10 '[ "$(kubectl -n argocd get application podinfo-ui -o jsonpath="{.status.sync.status}/{.status.health.status}")" = "Synced/Healthy" ]' || {
  kubectl -n argocd get application podinfo-ui -o jsonpath='{.status}' | head -c 1500; exit 1; }

run_cmd "kubectl -n argocd get application podinfo-ui"
run_cmd "kubectl -n apps-ui get deploy,svc,pods"
run_cmd "kubectl -n apps-ui get deploy podinfo-ui -o jsonpath='{.spec.replicas}'"
echo ""
run_cmd "kubectl -n apps-ui get deploy podinfo-ui -o jsonpath=\"{.spec.template.spec.containers[0].env[?(@.name=='PODINFO_UI_COLOR')].value}\""
echo ""
