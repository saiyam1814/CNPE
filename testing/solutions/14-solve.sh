#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl get providers"
run_cmd "kubectl get xrd"

echo ""
echo "\$ vim /root/composition.yaml   # complete the five TODO patches, then apply"
python3 - "$ROOTDIR/composition.yaml" <<'EOF'
import sys
path = sys.argv[1]
s = open(path).read()
todo_block = """        # TODO(1): spec.appName        -> Deployment metadata.name
        # TODO(2): spec.appName        -> pod template label 'app'
        # TODO(3): spec.appName        -> selector matchLabels 'app'
        # TODO(4): spec.desiredReplicas -> Deployment replicas
        # TODO(5): spec.containerImage  -> first container image"""
patches = """        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: spec.forProvider.manifest.spec.template.metadata.labels.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: spec.forProvider.manifest.spec.selector.matchLabels.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.desiredReplicas
          toFieldPath: spec.forProvider.manifest.spec.replicas
        - type: FromCompositeFieldPath
          fromFieldPath: spec.containerImage
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image"""
assert todo_block in s, "TODO block not found"
open(path, "w").write(s.replace(todo_block, patches))
print("patches completed")
EOF

run_cmd "kubectl apply -f $ROOTDIR/composition.yaml"
run_cmd "kubectl apply -f $ROOTDIR/app-xr.yaml"

echo "waiting for the XR to become Ready..."
retry 40 6 '[ "$(kubectl get xwebapp demo-site -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" 2>/dev/null)" = "True" ]' || {
  kubectl describe xwebapp demo-site | tail -20
  kubectl get objects.kubernetes.crossplane.io 2>/dev/null
  exit 1
}

run_cmd "kubectl get xwebapp demo-site"
run_cmd "kubectl get objects.kubernetes.crossplane.io"
run_cmd "kubectl -n compose-sandbox get deploy,svc"
run_cmd "kubectl -n compose-sandbox rollout status deploy/demo-site --timeout=120s"
run_cmd "kubectl -n compose-sandbox get deploy demo-site -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}'"
echo ""
