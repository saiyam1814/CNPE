# 16-grafana-dashboard — fixes

- **`cnpe/16-grafana-dashboard/verify2.sh`: renamed the shell variable `UID` to `DASH_UID`.**
  - `UID` is a readonly built-in variable in bash, so `UID=$(...)` failed with `line 15: UID: readonly variable`, the dashboard fetch used the wrong (empty-guarded) path, and the check exited 1 even though the dashboard existed and was correct. This is not a macOS quirk — it fails the same way under bash on the Killercoda kubeadm image, so the check could never pass there either.
  - The check's assertions (dashboard `coral-dashboard` exists, has a `timeseries` panel titled `Request Mix` with a `rate(http_requests_total[5m])` target) are unchanged — only the local variable name changed, so grading strength is identical.

Notes:
- `grafana/grafana:12.3.0` exists on Docker Hub (verified via the registry API) — no image tag change needed.
- Setup, step text, and solve script needed no changes. Full rerun passed: datasource `PromLab` (prometheus, default, `http://prom.obs.svc:9090`) + dashboard created via API, Prometheus returned live `rate(http_requests_total[5m])` data for all three handlers.
