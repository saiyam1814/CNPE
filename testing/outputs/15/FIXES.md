# 15-crossplane-xrd-claim — test report

**Result: PASS (first run, no fixes needed)**
**Wall time:** ~20 s (setup + solve + verify) on kind v1.36.1 / arm64, cluster `kind-cnpe-e`.
(Run back-to-back after scenario 14 — the shared Crossplane 1.20.0 +
provider-kubernetes v0.18.0 install was already present; helm upgrade --install was
idempotent and the setup completed quickly.)

## What was verified
- XRD `xbucketapps.platform.example.io` with `claimNames: BucketApp` reached
  Established + Offered in ~4 s; both `xbucketapps` and namespaced `bucketapps`
  appeared in `kubectl api-resources`.
- Composition `xbucketapp-objects` (`mode: Resources`, provider-kubernetes Object
  wrapping a ConfigMap) accepted.
- Claim `media-assets` in `team-apps` became SYNCED/READY in ~6 s; XR
  `media-assets-8dm6n` created; composed ConfigMap `media-assets-8dm6n` landed in
  `bucket-system` with `region=eu-west-1`, `size=small`.
- verify1.sh (XRD shape + Established/Offered) and verify2.sh (claim Ready +
  ConfigMap data) both passed.

## Fixes applied
None. Scenario files and `testing/solutions/15-solve.sh` unchanged.

## Killercoda notes
- Same stack notes as scenario 14: needs `helm` (present on Killercoda), all images
  multi-arch, provider Healthy wait can take ~1 min on a cold cluster (fresh
  Killercoda session installs Crossplane from scratch, so expect setup to take
  2–4 min there rather than the ~20 s seen on this warm shared cluster).
- On a standalone Killercoda run, `kubectl wait provider ... --for=condition=Healthy
  --timeout=600s` in setup covers the cold-start path; the claim flow itself has no
  external dependencies beyond pulling the provider/crossplane images.
