# 14-crossplane-composition-patch — test report

**Result: PASS (first run, no fixes needed)**
**Wall time:** ~62 s (setup + solve + verify) on kind v1.36.1 / arm64, cluster `kind-cnpe-e`.
(Setup shared with scenario 15; helm install of Crossplane 1.20.0 dominates.)

## What was verified
- Crossplane chart 1.20.0 + provider-kubernetes v0.18.0 installed; provider Healthy
  in ~23 s (DeploymentRuntimeConfig-pinned SA `provider-kubernetes`,
  cluster-admin binding, `ProviderConfig default` with InjectedIdentity all applied).
- `mode: Resources` composition accepted by Crossplane 1.20.0 — no deprecation
  rejection.
- Solve script's python TODO-block replacement in `$HOME/composition.yaml` (harness
  adaptation of /root) matched and inserted the five patches cleanly.
- XR `demo-site` became SYNCED/READY in ~7 s; composed Object resources
  (Deployment + Service) both SYNCED/READY.
- Composed deployment landed in `compose-sandbox` with `replicas=2`,
  `image=nginx:1.25`, selector `app=demo-site`; rollout completed.
- verify1.sh (five patch pairs present) and verify2.sh (XR Ready + composed
  Deployment/Service correctness + availability) both passed.

## Fixes applied
None. Scenario files and `testing/solutions/14-solve.sh` unchanged.

## Killercoda notes
- Needs `helm` on the host — present on Killercoda kubeadm images; locally it came
  from the machine PATH.
- Provider image `xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v0.18.0`
  and nginx:1.25 are multi-arch; amd64 fine.
- Provider took ~23 s to become Healthy on this machine; on Killercoda expect up to
  ~1 min (setup already waits with `kubectl wait --timeout=600s`).
