# 22-gatekeeper-image-tags — test report

**Result: PASS (first run, no fixes needed)**
**Wall time:** ~64 s (setup + solve + verify) on kind v1.36.1 / arm64, cluster `kind-cnpe-e`.

## What was verified
- Gatekeeper v3.23.0 manifest applied cleanly; `gatekeeper-controller-manager` and
  `gatekeeper-audit` rolled out.
- ConstraintTemplate `forbidfloatingtag` compiled without Rego errors (kind
  `ForbidFloatingTag` served).
- Constraint matching apps/* workloads, batch Job/CronJob and core Pods created;
  after the 20 s webhook sync in the solve script:
  - `busybox:latest` deployment **denied** ("uses floating tag :latest").
  - untagged `busybox` deployment **denied** ("uses an untagged image").
  - `busybox:1.36.1` deployment **admitted**.
- verify1.sh (constraint kinds coverage) and verify2.sh (deny/allow end state +
  live re-probe with `nginx:latest`) both passed.

## Fixes applied
None. Scenario files and `testing/solutions/22-solve.sh` unchanged.

## Killercoda notes
- Tested on arm64 kind; Gatekeeper v3.23.0 and busybox images are multi-arch, so
  amd64 kubeadm behaves the same.
- The 20 s sleep after creating the Constraint was sufficient locally; on slower
  Killercoda VMs the webhook sync may occasionally need a retry (step2.md already
  tells learners to retry).
- Setup relies only on `kubectl` + GitHub raw egress — no /usr/local/bin installs,
  nothing for the harness to adapt beyond /root paths.
