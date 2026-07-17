# Killercoda platform QA checklist

Everything in `cnpe/` passed end-to-end on kind (same Kubernetes minor, same
manifests, all images verified multi-arch amd64+arm64, all download URLs verified).
What kind **cannot** prove is Killercoda's own platform behavior. This checklist
covers exactly that gap. One pass through this = the course is verified for real.

**How to QA a lab:** open it logged-in as the creator → START → read the intro while
setup runs → do the steps (use the solution dropdowns to go fast) → hit CHECK on each
step → finish. If a background setup fails, the **Creator Debug Section** shows the
setup script's stdout/stderr (killercoda.com → Creator → Debug).

**If something breaks:** paste me the lab id + the debug-section tail (or the failing
command's output) and I'll fix and re-sync within minutes. Setup scripts log
everything to `/var/log/cnpe-setup.log` inside the VM too.

---

## Platform risks these labs share (why QA matters)

| # | Risk | Which labs | What to look for |
|---|------|-----------|------------------|
| 1 | **CNI NetworkPolicy enforcement** - unconfirmed which CNI the kubeadm image runs | 04 | After creating deny-all in step 1, the squad-client curl must **time out**. If it still answers, the CNI doesn't enforce → tell me, I'll adjust the lab text + verify (objects-only) |
| 2 | **Memory ceilings** (2GB/4GB VMs; kind was uncapped) | 07, 24 (Istio) · 06 (Argo CD) · 17 (prom-operator) · 05 (Prometheus+OpenCost) | Pods stuck `Pending`/`OOMKilled` during setup → check `kubectl get pods -A` and debug section |
| 3 | **Setup duration** on slower VMs | all 4GB labs | Intro "Preparing…" should finish in ≤ 4–5 min. Longer → debug section |
| 4 | **Egress** to sigstore/gcr/ghcr/helm repos | 23 (rekor+fulcio+gcr) · 25 (trivy DB) · 05, 14, 15 (helm, xpkg) | Denials/timeouts in setup log or during verify steps |
| 5 | **Killercoda UI wiring** - `{{exec}}` buttons, TRAFFIC port links, CHECK verify hooks | all (16, 18 use traffic links most) | Click one exec block + one traffic link + CHECK per lab |

---

## Priority 1 - run these five first (highest platform risk)

- [ ] **04-networkpolicy-tenant-isolation** - THE CNI check (risk 1). Both curls in
      step 1/2 must behave as the text says. ~2 min setup.
- [ ] **07-argo-rollouts-canary** - Istio + Rollouts on a 4GB VM (risk 2). Watch:
      istiod Running, rollout goes Healthy, VS weights move 20→40→100, traffic-gen
      logs show a `nginx/1.25` vs `nginx/1.26` mix. ~3 min setup.
- [ ] **06-argocd-gitops-podinfo** - Argo CD memory + GitHub egress. App reaches
      Synced/Healthy. ~3 min setup.
- [ ] **23-kyverno-cosign-verify** - sigstore egress (risk 4): signed distroless
      admitted, busybox denied. ~2–3 min setup.
- [ ] **05-opencost-rightsizing** - the slowest setup (helm Prometheus + OpenCost);
      allocation data appears within ~2 min of setup finishing; `kubectl cost` table
      renders. ~4 min setup.

## Priority 2 - heavier stacks, same patterns as P1

- [ ] **26-flagger-canary** - istio + flagger + prometheus on 4GB (the heaviest
      bonus lab); canary Initialized in ~1 min, full promotion ~3 min after the
      image change.
- [ ] **27-linkerd-authorization** - linkerd edge + Gateway API CRDs; Server
      default-denies, then storefront 200 / reporting 403.
- [ ] **24-istio-authorizationpolicy** - istio again; storefront allowed, reporting
      `RBAC: access denied` (verify tolerates the ~45s Envoy drain).
- [ ] **17-prometheusrule-alert** - prom-operator bundle on 4GB; rule loads, alert
      reaches pending/firing after ~5 min (`for: 5m` - expected wait).
- [ ] **18-jaeger-tracing-otel** - pip install at container start (~1 min); Jaeger UI
      via traffic port 16686; exception.json CHECK passes.
- [ ] **25-tekton-trivy-scan-gate** - trivy DB download (~100MB); nginx:1.16 run
      fails, distroless run deploys.
- [ ] **12-tekton-triggers-webhook** - EventListener up, curl spawns a run.
- [ ] **14/15-crossplane-…** - provider Healthy in ≤ 2 min; XR/claim goes Ready.
- [ ] **16-grafana-dashboard** - traffic port 3000, anonymous admin works, datasource
      + dashboard CHECKs pass (do it via UI to test the real exam motion).

## Priority 3 - pure-k8s labs (lowest risk; spot-check any two)

- [ ] 01-resourcequota-limitrange   ·  [ ] 02-pvc-storageclasses
- [ ] 03-hpa-autoscaling (metrics-server flag works on kubeadm)
- [ ] 08-argo-rollouts-bluegreen    ·  [ ] 09/10-argo-workflows-…
- [ ] 11-tekton-kubectl-apply-task  ·  [ ] 13-crd-featureflag
- [ ] 19-broken-stack-remediation (relies on the image's default StorageClass
      `local-path` for the PVC - confirm PVC binds)
- [ ] 20-rbac-ci-bot                ·  [ ] 21-pod-security-standards
- [ ] 22-gatekeeper-image-tags

---

## Known platform-specific notes (already handled, verify in passing)

- **19**: the missing PVC uses the cluster default SC - on the kubeadm image that is
  `local-path` (present per Killercoda docs). If the PVC sits Pending, that assumption
  broke.
- **03**: metrics-server is patched with `--kubelet-insecure-tls` via `kubectl patch`
  (portable). `kubectl top` needs ~60s of runway.
- **24**: verify polls up to ~60s on the deny check by design (Envoy drain);
  a slow CHECK there is normal, not stuck.
- **Scenario time limit**: free accounts get 60 min/scenario - every lab fits with
  big margin (longest ~15 min including setup).
