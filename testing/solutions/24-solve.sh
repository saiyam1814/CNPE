#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n batch exec reporting -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname"
echo ""

echo ""
echo "\$ kubectl apply -f authz.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: checkout-allow-storefront
  namespace: payments
spec:
  selector:
    matchLabels:
      app: checkout
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/web/sa/storefront"
EOF

run_cmd "kubectl -n payments get authorizationpolicy"
echo "letting the policy propagate to sidecars..."
sleep 15

echo ""
echo "\$ # storefront (allowed identity):"
retry 6 5 'kubectl -n web exec storefront -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname | grep -q checkout'
kubectl -n web exec storefront -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname
echo ""

echo ""
echo "\$ # reporting (denied identity):"
kubectl -n batch exec reporting -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname || true
echo ""
