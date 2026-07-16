#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n kyverno get pods"

echo ""
echo "\$ kubectl apply -f supply-chain-signoff.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: supply-chain-signoff
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: require-keyless-cosign
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences: ["*"]
          attestors:
            - entries:
                - keyless:
                    issuer: "https://accounts.google.com"
                    subject: "keyless@distroless.iam.gserviceaccount.com"
                    rekor:
                      url: https://rekor.sigstore.dev
EOF

echo "waiting for policy Ready..."
retry 30 4 '[ "$(kubectl get clusterpolicy supply-chain-signoff -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}")" = "True" ]' || exit 1
run_cmd "kubectl get clusterpolicy"

echo ""
echo "\$ kubectl apply -f ok-signed-web.yaml   # signed distroless - must be ADMITTED"
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ok-signed-web
  namespace: policy-sandbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ok-signed-web
  template:
    metadata:
      labels:
        app: ok-signed-web
    spec:
      containers:
        - name: web
          image: gcr.io/distroless/base:debug-nonroot
          command: ["/busybox/sh", "-c", "while true; do sleep 3600; done"]
EOF

echo ""
echo "\$ kubectl apply -f blocked-plain-web.yaml   # unsigned - must be DENIED"
cat <<'EOF' | kubectl apply -f - && { echo "!! unsigned image was admitted"; exit 1; } || echo "-> denied (good)"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blocked-plain-web
  namespace: policy-sandbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blocked-plain-web
  template:
    metadata:
      labels:
        app: blocked-plain-web
    spec:
      containers:
        - name: web
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
EOF

run_cmd "kubectl -n policy-sandbox wait --for=condition=available deploy/ok-signed-web --timeout=180s"
run_cmd "kubectl -n policy-sandbox get deploy,pods"
run_cmd "kubectl -n policy-sandbox get pod -l app=ok-signed-web -o jsonpath='{.items[0].spec.containers[0].image}'"
echo ""
