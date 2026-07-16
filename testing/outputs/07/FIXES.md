# 07-argo-rollouts-canary

No fixes needed.

- PASS on kind-cnpe-c first attempt, wall time ~2m26s (istio minimal + argo-rollouts install,
  rollout rev1, canary to nginx:1.26 with VirtualService weights 20 -> 40 -> 100, full
  promotion, legacy deploy scaled to 0).
- traffic-gen saw `server: envoy` throughout, confirming sidecar routing.
