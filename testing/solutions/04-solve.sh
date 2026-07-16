#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n other-squad exec squad-client -- curl -s --max-time 5 http://api.tenant-red.svc:8080/hostname || echo '(no answer)'"

echo ""
echo "\$ kubectl apply -f deny-all-ingress.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: tenant-red
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF

echo ""
echo "\$ kubectl apply -f allow-api-from-edge.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-from-edge
  namespace: tenant-red
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress", "Egress"]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              purpose: edge
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
EOF

run_cmd "kubectl -n tenant-red get networkpolicy"
run_cmd "kubectl -n tenant-red describe networkpolicy allow-api-from-edge"

# Connectivity proof (only meaningful with an enforcing CNI)
if kubectl -n kube-system get pods 2>/dev/null | grep -qE "cilium|calico"; then
  run_cmd "kubectl -n ingress-gw exec edge-client -- curl -s --max-time 5 http://api.tenant-red.svc:8080/hostname"
  run_cmd_expect_fail "kubectl -n other-squad exec squad-client -- curl -s --max-time 4 http://api.tenant-red.svc:8080/hostname"
  run_cmd "kubectl -n tenant-red exec deploy/api -- nslookup kubernetes.default.svc.cluster.local | head -2"
else
  echo "(CNI does not enforce NetworkPolicy on this test cluster - objects verified, enforcement happens on Killercoda)"
fi
