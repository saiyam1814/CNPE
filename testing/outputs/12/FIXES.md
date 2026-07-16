# 12-tekton-triggers-webhook

Fixes applied: **none** — passed unmodified on the first run.

- Setup (Tekton Pipelines v1.14.0 + Triggers v0.36.0 + interceptors), the manual
  baseline PipelineRun, the TriggerTemplate/TriggerBinding/EventListener trio, the
  port-forward + webhook POST (`{"after": "4f2c1ab"}`), and both verifies all worked
  as written.
- `deploy/el-build-ship-el` became available in ~11s after applying the EventListener;
  the webhook-spawned PipelineRun succeeded with `gitrevision=4f2c1ab` in the logs.

Notes:

- This run shared the cluster with scenario 11, so Tekton Pipelines was already
  installed and setup only added Triggers (+ RBAC, Task, Pipeline). On a fresh
  Killercoda cluster the full Pipelines+Triggers install runs; both components get a
  `rollout status --timeout=600s` wait, so only total setup time differs (~2-3 min).
- The solve script's port-forward on 127.0.0.1:8080 was confirmed free before the run
  and is killed by the script afterwards; on Killercoda (root, fresh VM) the port is
  free by default.

Result: PASS on kind-cnpe-d. Wall time 57s (Pipelines pre-installed; expect ~3 min
fresh). Namespace `ci-otter` deleted afterwards so scenario 25 can recreate its own
`build-ship` pipeline from scratch.
