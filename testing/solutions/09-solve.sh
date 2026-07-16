#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n argo get pods"
run_cmd "kubectl auth can-i create deployments -n demo-reef --as=system:serviceaccount:workflows:workflow-runner"

echo ""
echo "\$ kubectl apply -f deploy-kit.yaml"
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: deploy-kit
  namespace: workflows
spec:
  serviceAccountName: workflow-runner
  entrypoint: ship
  arguments:
    parameters:
      - name: appName
      - name: targetNs
      - name: count
      - name: containerImage
  templates:
    - name: ship
      inputs:
        parameters:
          - name: appName
          - name: targetNs
          - name: count
          - name: containerImage
      resource:
        action: apply
        manifest: |
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: {{inputs.parameters.appName}}
            namespace: {{inputs.parameters.targetNs}}
          spec:
            replicas: {{inputs.parameters.count}}
            selector:
              matchLabels:
                app: {{inputs.parameters.appName}}
            template:
              metadata:
                labels:
                  app: {{inputs.parameters.appName}}
              spec:
                containers:
                  - name: main
                    image: {{inputs.parameters.containerImage}}
EOF

run_cmd "kubectl -n workflows get workflowtemplate"

run_cmd "argo submit --from workflowtemplate/deploy-kit -n workflows -p appName=catalog-ui -p targetNs=demo-reef -p count=3 -p containerImage=httpd:2.4 --wait --log"

run_cmd "argo list -n workflows"
run_cmd "kubectl -n demo-reef get deploy catalog-ui"
run_cmd "kubectl -n demo-reef rollout status deploy/catalog-ui --timeout=180s"
