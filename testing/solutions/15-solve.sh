#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

echo "\$ kubectl apply -f xrd.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xbucketapps.platform.example.io
spec:
  group: platform.example.io
  names:
    kind: XBucketApp
    plural: xbucketapps
  claimNames:
    kind: BucketApp
    plural: bucketapps
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [region, size]
              properties:
                region:
                  type: string
                size:
                  type: string
EOF

echo "waiting for Established + Offered..."
retry 30 4 '[ "$(kubectl get xrd xbucketapps.platform.example.io -o jsonpath="{.status.conditions[?(@.type==\"Offered\")].status}")" = "True" ]' || exit 1
run_cmd "kubectl get xrd xbucketapps.platform.example.io"
run_cmd "kubectl api-resources --api-group=platform.example.io"

echo ""
echo "\$ kubectl apply -f composition.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xbucketapp-objects
spec:
  compositeTypeRef:
    apiVersion: platform.example.io/v1alpha1
    kind: XBucketApp
  mode: Resources
  resources:
    - name: bucket
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: default
          forProvider:
            manifest:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: placeholder
                namespace: bucket-system
                labels:
                  platform.example.io/kind: bucket
              data:
                region: placeholder
                size: placeholder
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.region
          toFieldPath: spec.forProvider.manifest.data.region
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.manifest.data.size
EOF

echo ""
echo "\$ kubectl apply -f claim.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: platform.example.io/v1alpha1
kind: BucketApp
metadata:
  name: media-assets
  namespace: team-apps
spec:
  region: eu-west-1
  size: small
EOF

echo "waiting for the claim to be Ready..."
retry 40 6 '[ "$(kubectl -n team-apps get bucketapp media-assets -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" 2>/dev/null)" = "True" ]' || {
  kubectl -n team-apps describe bucketapp media-assets | tail -15
  kubectl get xbucketapp 2>/dev/null
  exit 1
}

run_cmd "kubectl -n team-apps get bucketapp"
run_cmd "kubectl get xbucketapp"
run_cmd "kubectl -n bucket-system get cm -l platform.example.io/kind=bucket"
run_cmd "kubectl -n bucket-system get cm -l platform.example.io/kind=bucket -o jsonpath='{.items[0].data}'"
echo ""
