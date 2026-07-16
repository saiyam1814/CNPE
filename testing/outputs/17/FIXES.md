# 17-prometheusrule-alert — fixes

- **`cnpe/17-prometheusrule-alert/setup.sh`: wait for `prometheus-main-0` to be *created* before `kubectl wait --for=condition=ready`.**
  - On a fresh cluster the Prometheus Operator takes a while (image pull + reconcile) to create the `prometheus-main-0` StatefulSet pod. The original `kubectl -n monitoring wait --for=condition=ready pod/prometheus-main-0 --timeout=300s || true` returned instantly with `Error from server (NotFound)` (masked by `|| true`), so setup declared success while Prometheus didn't exist yet. The solve script then port-forwarded `svc/prometheus-main` immediately, the forward died (no endpoints), and every subsequent rules-API poll failed → run 1 timed out after 3m16s.
  - Fix: a bounded existence poll (`for i in $(seq 1 60); do kubectl get pod prometheus-main-0 && break; sleep 5; done`, i.e. up to 5 min) before the readiness wait. Verified in the rerun's setup.log: pod found, `condition met`. Same behavior applies on Killercoda, where the operator install is also part of setup.

Not a scenario bug, for the record: during one rerun the local Docker daemon crashed mid-verify (kubectl `connection refused`), which produced a spurious verify failure. Docker recovered and the clean rerun passed both verifies (alert `FrontendHighErrorRate` reached `pending` with value ≈ 8.4% > 5% threshold) in ~1m40s (operator images already cached; first install takes longer).

Verify scripts, step text, solve script, and pinned versions unchanged.
