# 25-tekton-trivy-scan-gate

Fixes applied:

- **Bug (would also fail on Killercoda):** the setup-created `deploy-image` Task used a
  `script:` step (`#!/bin/sh`, with a pipe: `kubectl create deployment … -o yaml |
  kubectl apply -f -`) on image `rancher/kubectl:v1.28.0`. That image ships only
  `/bin/kubectl` — no `/bin/sh` on amd64 or arm64 (verified both variants) — so the
  deploy step would die with `fork/exec /tekton/scripts/…: no such file or directory`
  exactly as it did in scenario 11. Replaced the image with
  **`bitnamilegacy/kubectl:1.28.9`** (multi-arch, Debian-based, has `/bin/sh`) in
  `cnpe/25-tekton-trivy-scan-gate/setup.sh`. Fix applied before this scenario's first
  run (the identical failure was observed live in scenario 11); with it, the clean-image
  run's deploy step worked first try.
- No other changes. The trivy scan Task (`aquasec/trivy:0.58.1`), step markdown, solve
  script, and both verifies ran unmodified.

Notes:

- Trivy DB: downloaded from `mirror.gcr.io/aquasec/trivy-db:2` (trivy 0.58.1's default
  mirror), ~100 MB in ~6s here; no Docker Hub `TOOMANYREQUESTS`, so the
  `--db-repository public.ecr.aws/aquasecurity/trivy-db` fallback documented in
  step2.md was not needed.
- Gate behaviour confirmed: `nginx:1.16` run **Failed** at the scan task (wall of
  CRITICAL CVEs), `shipped` Deployment absent (NotFound); the
  `gcr.io/distroless/static:nonroot` run **Succeeded** (Total: 0 CRITICAL) and deployed
  `shipped` with the distroless image. verify2 checks both runs plus the deployed image.
- `nginx:1.16` publishes an arm64 manifest, so the scan behaves the same on this arm64
  kind cluster as on Killercoda amd64.

Result: PASS on kind-cnpe-d. Wall time 1m43s (Tekton Pipelines pre-installed from
scenarios 11/12; the vulnerable-image scan including first DB download took ~57s,
the clean run ~34s). Expect ~3-4 min on a fresh Killercoda cluster including the
Tekton install.
