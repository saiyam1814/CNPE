#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

echo "\$ kubectl apply -f featureflag-crd.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: featureflags.toggle.acme.dev
spec:
  group: toggle.acme.dev
  names:
    kind: FeatureFlag
    listKind: FeatureFlagList
    plural: featureflags
    singular: featureflag
    shortNames: [ff]
  scope: Namespaced
  versions:
    - name: v1beta1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [key, enabled, rolloutPercent]
              properties:
                key:
                  type: string
                enabled:
                  type: boolean
                rolloutPercent:
                  type: integer
                  minimum: 0
                  maximum: 100
EOF

run_cmd "kubectl wait --for=condition=established crd/featureflags.toggle.acme.dev --timeout=30s"
run_cmd "kubectl apply -f $ROOTDIR/checkout-express.yaml"
run_cmd "kubectl get ff -n flags-lab"

echo ""
echo "\$ kubectl apply -f bad-percent.yaml   # must FAIL (rolloutPercent 150)"
cat <<'EOF' | kubectl apply -n flags-lab -f - && { echo "!! should have been rejected"; exit 1; } || echo "-> rejected (good)"
apiVersion: toggle.acme.dev/v1beta1
kind: FeatureFlag
metadata:
  name: bad-percent
spec:
  key: some.flag
  enabled: true
  rolloutPercent: 150
EOF

echo ""
echo "\$ kubectl apply -f no-enabled.yaml   # must FAIL (missing required field)"
cat <<'EOF' | kubectl apply -n flags-lab -f - && { echo "!! should have been rejected"; exit 1; } || echo "-> rejected (good)"
apiVersion: toggle.acme.dev/v1beta1
kind: FeatureFlag
metadata:
  name: no-enabled
spec:
  key: some.flag
  rolloutPercent: 10
EOF

run_cmd "kubectl api-resources --api-group=toggle.acme.dev"
