# 18-jaeger-tracing-otel — fixes

Scenario files needed no fixes: setup, step text, and both verify scripts passed unmodified on the first run. `jaegertracing/all-in-one:1.62.0` exists on Docker Hub (verified via the registry API) — no tag change needed.

- **`testing/solutions/18-solve.sh`: made the session-log output deterministic (cosmetic, no grading impact).**
  - Before: the first `kubectl logs deploy/span-switch --tail=3` often printed nothing (the container was still pip-installing the OTel packages), and the post-`set env` log printed `Found 2 pods, using pod/...` + `tracing DISABLED` because `kubectl logs deploy/...` picked the *old terminating* pod during the rollout.
  - After: bounded retries wait for "tracing DISABLED" before the first log call, and for the old pod to terminate plus "tracing ENABLED" to appear before the second. The session log now shows the intended before/after story (DISABLED → set env → ENABLED → service in Jaeger → error-span exception extracted). A fixed `sleep 10` was replaced by these condition-based waits.

Rerun from scratch passed in ~2m46s: `span-switch` appeared in Jaeger's service list, the error trace carried `exception.message = "connection refused to payment-svc:8080"`, and `exception.json` matched verify2 exactly.
