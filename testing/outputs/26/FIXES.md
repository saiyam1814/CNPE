# 26-flagger-canary

No fixes needed — passed on the first run.

- PASS on kind (arm64), wall time ~5m50s: istio minimal + addon prometheus + flagger
  1.43.0 install (~2.5 min), canary Initialized (~1 min), progressive analysis
  20→40→60→80→100 with request-success-rate ≥ 99 (~2.5 min), automatic promotion,
  primary on nginx:1.26. Both verifies pass.
- The traffic-gen pod's steady in-mesh requests were enough for the success-rate
  metric — no flagger-loadtester needed.
- Killercoda note: same install path (helm + istio release tarball); expect setup
  ~3-4 min on the 4GB image. All images multi-arch.
