# 11-tekton-kubectl-apply-task

Fixes applied:

- **Bug (would also fail on Killercoda):** the `kubectl-apply` Task used a `script:`
  step (`#!/bin/sh`) with image `rancher/kubectl:v1.28.0`, but that image contains only
  `/bin/kubectl` — no shell on **any** architecture (verified `/bin/sh` is absent in both
  the arm64 and amd64 variants). Tekton materializes `script:` as a file exec'd via its
  shebang, so the step died with
  `Error executing command: fork/exec /tekton/scripts/script-0-…: no such file or directory`
  and the PipelineRun failed.
- Replaced the image with **`bitnamilegacy/kubectl:1.28.9`** (multi-arch amd64+arm64,
  Debian-based, ships `/bin/sh`; verified `sh -c` works on both arches). This is the
  Bitnami image the scenario originally wanted, from the archive registry Bitnami moved
  its versioned tags to in 2025. Files touched:
  - `cnpe/11-tekton-kubectl-apply-task/intro.md` (task requirements + the historical note)
  - `cnpe/11-tekton-kubectl-apply-task/step1.md` (requirements list + solution block)
  - `testing/solutions/11-solve.sh`
- Alternatives considered: `alpine/kubectl` has no 1.28 tag; `registry.k8s.io/kubectl`
  and `rancher/kubectl` are shell-less; `bitnami/kubectl` versioned tags are gone.
  A `command:`-form step can't satisfy the lab's "write the param to a file" requirement
  without a shell, so the image swap is the smallest fix that keeps the exam wording.
- `verify1.sh` unchanged — it only requires `"kubectl" in image`, which
  `bitnamilegacy/kubectl:1.28.9` satisfies. No checks weakened.

Notes:

- First failed run also showed `tkn pipelinerun list` hitting a different cluster —
  a concurrent test batch had switched the shared kubectl current-context. Local-test
  artifact only (Killercoda runs are isolated); this batch now pins
  `KUBECONFIG=/tmp/cnpe-d.kubeconfig` for every harness invocation.

Result: PASS on kind-cnpe-d. Wall time ~36s on rerun (Tekton already installed);
first run with full Tekton v1.14.0 install was ~1m50s to the point of failure, so expect
~2min end-to-end on a fresh cluster. No Tekton webhook "connection refused" seen —
the existing `rollout status` + `sleep 5` was sufficient here.
