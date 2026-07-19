# 07-argo-rollouts-canary

No fixes needed.

- PASS on kind-cnpe-c first attempt, wall time ~2m26s (istio minimal + argo-rollouts install,
  rollout rev1, canary to nginx:1.26 with VirtualService weights 20 -> 40 -> 100, full
  promotion, legacy deploy scaled to 0).
- traffic-gen saw `server: envoy` throughout, confirming sidecar routing.

## 2026-07-19 field report fix (thanks Vishal)
- On Killercoda's 2-vCPU VMs the default istiod request (500m) plus 100m per
  sidecar left rollout pods Pending ("insufficient cpu"). setup.sh now installs
  istio with pilot requests 100m/512Mi and proxy requests 10m/64Mi. Re-tested:
  full canary passes; total node CPU requests ~1120m. Same flags applied
  preemptively to labs 24 and 26.
