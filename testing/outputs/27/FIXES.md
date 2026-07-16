# 27-linkerd-authorization

One real fix (would also fail on Killercoda):

- **Gateway API CRDs are a hard prerequisite for modern Linkerd** (edge-26.x):
  `linkerd install --crds` refuses to render until
  `gateway-api v1.2.1 standard-install.yaml` is applied. First run failed with
  `no matches for kind "Server" in version policy.linkerd.io/v1beta3` because the
  whole control-plane install had silently no-opped ("no objects passed to apply").
  Fix: setup.sh now applies the Gateway API CRDs (server-side) before
  `linkerd install --crds`. Clean-room rerun passed end-to-end in ~2m15s.
- Cosmetic text fix: modern Linkerd injects the proxy as a **native sidecar**
  (initContainers: linkerd-init, linkerd-proxy) — step1 text and solve script now
  look there instead of `.spec.containers`.

Verified behavior:
- Server alone → both callers denied (curl exit 22 / 403): default-deny confirmed.
- MeshTLSAuthentication + AuthorizationPolicy → storefront answers,
  reporting gets `HTTP:403` from the proxy. Both verifies pass.
- `--set proxyInit.runAsRoot=true` used for kind compatibility; harmless on
  Killercoda kubeadm.
