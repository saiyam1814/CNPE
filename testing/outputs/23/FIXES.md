# 23-kyverno-cosign-verify — test report

**Result: PASS (first run, no fixes needed)**
**Wall time:** ~88 s (setup + solve + verify) on kind v1.36.1 / arm64, cluster `kind-cnpe-e`.

## What was verified
- Kyverno v1.13.6 installed server-side; all four controllers Running.
- ClusterPolicy `supply-chain-signoff` (keyless attestor, issuer
  `https://accounts.google.com`, subject `keyless@distroless.iam.gserviceaccount.com`,
  rekor `https://rekor.sigstore.dev`) became Ready in ~4 s.
- `gcr.io/distroless/base:debug-nonroot` deployment **admitted**; Kyverno mutated the
  image to the verified digest
  `gcr.io/distroless/base:debug-nonroot@sha256:73532e54641a478ac4a0f8ebbe31e525f2c36af57a2fe10a0a3df69c40c824a6`
  and the pod reached Ready.
- `busybox:1.36` deployment **denied** with
  `autogen-require-keyless-cosign: 'failed to verify image docker.io/busybox:1.36: .attestors[0].entries[0].keyless: no signatures found'`.
- verify1.sh (policy shape + Ready) and verify2.sh (signed available, unsigned absent,
  live unsigned-pod probe denied) both passed.

## Fixes applied
None. The distroless keyless identity (accounts.google.com /
keyless@distroless.iam.gserviceaccount.com) is still valid upstream as of this test —
no policy or book-text changes required.

## Killercoda notes
- Requires egress to `gcr.io`, `rekor.sigstore.dev` and `fulcio.sigstore.dev`; all
  reachable from the local run. Killercoda VMs have general egress, but if sigstore is
  slow the policy's `webhookTimeoutSeconds: 30` (the max) is already in place; the
  first verification took only a few seconds here.
- Images are multi-arch (distroless base, busybox, kyverno v1.13.6) — amd64 fine.
- Cleanup gotcha (relevant to any follow-on scenario, not to Killercoda's throwaway
  VMs): `kubectl delete -f install.yaml` leaves the runtime-generated
  `kyverno-*-webhook-cfg` validating/mutating webhook configurations behind — they
  must be deleted separately or they can block later admissions.
