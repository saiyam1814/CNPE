# 06-argocd-gitops-podinfo

No fixes needed.

- PASS on kind-cnpe-c, wall time ~1m24s (setup + solve + verify).
- Note (local-only flake, no file changes): on the first attempt the kind node pulled a
  truncated copy of `quay.io/argoproj/argocd:v3.2.6` (binary 92MB instead of 203MB), so every
  argocd container segfaulted (exit 139) and the redis `secret-init` never created the
  `argocd-redis` secret. Recreating the cluster and re-pulling fixed it. Not a scenario bug;
  would not affect Killercoda.
