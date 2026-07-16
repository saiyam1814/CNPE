#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n payments get pod -l app=checkout -o jsonpath='init: {.items[0].spec.initContainers[*].name}{\"\\n\"}main: {.items[0].spec.containers[*].name}{\"\\n\"}'"
run_cmd "kubectl -n batch exec reporting -c curl -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname"
echo ""

echo ""
echo "\$ kubectl apply -f checkout-server.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: policy.linkerd.io/v1beta3
kind: Server
metadata:
  name: checkout
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: checkout
  port: 8080
  proxyProtocol: HTTP/1
EOF

sleep 8
echo ""
echo "\$ # a Server with no authorization denies EVERYONE:"
run_cmd_expect_fail "kubectl -n web exec storefront -c curl -- curl -sf --max-time 5 http://checkout.payments.svc:8080/hostname"
run_cmd_expect_fail "kubectl -n batch exec reporting -c curl -- curl -sf --max-time 5 http://checkout.payments.svc:8080/hostname"

echo ""
echo "\$ kubectl apply -f authz.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: policy.linkerd.io/v1alpha1
kind: MeshTLSAuthentication
metadata:
  name: storefront-only
  namespace: payments
spec:
  identities:
    - "storefront.web.serviceaccount.identity.linkerd.cluster.local"
---
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: checkout-allow-storefront
  namespace: payments
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: checkout
  requiredAuthenticationRefs:
    - group: policy.linkerd.io
      kind: MeshTLSAuthentication
      name: storefront-only
EOF

sleep 8
echo ""
echo "\$ # storefront (allowed identity):"
retry 6 5 'kubectl -n web exec storefront -c curl -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname | grep -q checkout'
kubectl -n web exec storefront -c curl -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname
echo ""

echo ""
echo "\$ # reporting (denied identity):"
kubectl -n batch exec reporting -c curl -- curl -sw ' HTTP:%{http_code}' --max-time 5 http://checkout.payments.svc:8080/hostname || true
echo ""
