# 24-istio-authorizationpolicy — test results and fixes

**Result: PASS** (verify1 + verify2) on kind v1.36.1 (`kind-cnpe-f`, arm64 darwin),
Istio 1.30.2 minimal profile.

- Full run wall time: **~30-35s** (istio install + workloads + solve + verify);
  two consecutive clean-room passes after the fix.
- First run: verify1 PASS, verify2 FAIL — flaky, and reproducibly so (2 of 3
  pre-fix runs failed the same way).

## Root cause of the verify2 flake — stale Envoy connection, not propagation lag

Sequence in the failing runs: the solve script applied the AuthorizationPolicy,
waited 15s, saw storefront allowed and reporting get `RBAC: access denied` — then
verify2, seconds later, saw reporting get a **successful** `checkout-...` answer
again. Instrumented verify2 confirmed: `reporting: [checkout-766bcdc85-6mq9m]`.

This is Envoy listener-drain behavior, not slow policy propagation: reporting's
sidecar pools its upstream mTLS connection to checkout's sidecar. When the RBAC
filter is added, the old filter chain keeps serving **existing** connections during
the drain window (up to ~45s), while new connections hit the new chain. Requests
alternate between the stale pooled connection (allowed) and fresh ones (denied).
Measured on this cluster after a fresh policy apply with a pre-warmed connection:
allowed at t+2s and t+6s, denied at t+4s, stable denial from t+8s onward.

## Fixes

1. **`verify2.sh`** — made both checks race-tolerant without weakening them:
   - storefront (allowed) check: bounded retry, 4 × 5s; the assertion is unchanged
     (response must contain the pod hostname `checkout-...`).
   - reporting (denied) check: polls up to 12 × 5s and passes only when a request
     is denied (RBAC message) or stops returning the payload. If the intruder
     *keeps* getting answers past the drain window, the check still fails.
2. **`testing/solutions/24-solve.sh`** — the final "denied identity" demonstration
   now waits for **two consecutive** denials (up to ~60s) before printing, so the
   session log always shows the settled state.
3. **`step2.md`** — added one troubleshooting bullet to the existing
   "Both blocked? Neither blocked?" details block explaining that an intruder curl
   that still succeeds right after `apply` is usually a stale pre-policy connection
   that Envoy drains within ~45s. Exam wording otherwise untouched.

No changes to setup.sh, verify1.sh, the policy YAML, or any pinned version
(Istio stays 1.30.2; `istioctl version` in testing/bin matches: 1.30.2).

## Killercoda notes

- The drain race is platform-independent Envoy behavior — it would bite on
  Killercoda exactly the same way if a student clicks "Check" quickly after
  applying the policy. The verify2 fix covers it there too.
- The failure path of verify2 now takes up to ~60s before returning 1 (it polls
  while the intruder keeps succeeding). Success path returns in seconds.
- Setup script untouched: on Killercoda (amd64, root) it downloads linux istioctl
  into /opt and symlinks /usr/local/bin as designed; the harness redirected those
  to a scratch dir locally and used the darwin istioctl 1.30.2 from testing/bin.
- istiod (minimal profile) scheduled instantly on this dedicated cluster; on a
  shared 4GB kubeadm node CPU pressure is the main risk, as already noted.
