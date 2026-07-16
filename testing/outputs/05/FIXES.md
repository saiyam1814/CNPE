# 05-opencost-rightsizing — test results and fixes

**Result: PASS** (verify1 + verify2) on kind v1.36.1 (`kind-cnpe-f`, arm64 darwin).

- First run: FAILED after ~6 min (solve script's 5-min allocation poll exhausted).
- Final clean-room rerun after fixes (fresh namespaces, fresh prometheus + opencost): **PASS in 2m05s** wall time. An intermediate warm-cluster rerun passed in 35s.

## Fix 1 — opencost.yaml removed upstream (setup.sh, pinned version change)

`https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml`
now returns **404**: the OpenCost project deleted the standalone manifest from the
develop branch (Helm-only installs now; see the README note "The standalone
Kubernetes manifest files have been removed"). `curl -sL` happily saved the 404 body,
`kubectl apply` failed with `apiVersion not set, kind not set`, no `opencost`
Deployment ever existed, and the solve script's allocation poll timed out.

**Fix:** pin the manifest to the last release tag that still ships it:

```
https://raw.githubusercontent.com/opencost/opencost/v1.117.0/kubernetes/opencost.yaml
```

(v1.118.0 already 404s; v1.117.0 verified 200.) This is arch/OS-independent — the
develop URL is equally dead on Killercoda. The pinned manifest's
`PROMETHEUS_SERVER_ENDPOINT` is `http://prometheus-server.prometheus-system.svc`,
which matches this scenario's Prometheus install exactly — no env patch needed
(confirmed via `kubectl -n opencost get deploy opencost -o yaml | grep -A2 PROMETHEUS`).
The `extraScrapeConfigs.yaml` URL on develop still exists (200) and was left alone.

## Fix 2 — kubectl cost needs --allocation-path (step1.md, finish.md, 05-solve.sh)

`kubectl-cost` v0.6.6 (current latest; the setup installs "latest", the darwin test
binary is the same version) defaults `--allocation-path` to `/model/allocation`,
which only exists on **Kubecost**. Against OpenCost it fails with
`received non-200 status code 404`. Working form, verified against the live API:

```
kubectl cost namespace --service-name opencost --service-port 9003 -N opencost \
  --allocation-path /allocation/compute --window 10m --show-cpu --show-memory
```

Added `--allocation-path /allocation/compute` to the command in `step1.md` (with a
one-line explanation), the key-facts line in `finish.md`, and the best-effort
invocation in `testing/solutions/05-solve.sh`. The curl allocation API path
(authoritative for verification) was already correct and untouched.

## Observation (no change made)

In the first ~60s of a fresh install the allocation API can report tiny *negative*
totalCost values while the first scrape windows settle; they turn positive shortly
after. Ordering can be misleading in that window, but nothing graded depends on the
cost values (verify checks files/replicas/labels), and the sizes are so far apart
(25m/1 vs 300m/3) that the ranking is unambiguous once real data lands.

## Killercoda notes

- The 404 fix applies identically there (upstream removal, not an arch issue).
- Setup's `kubectl-cost` install resolves "latest" → v0.6.6 today, the exact version
  the `--allocation-path` fix was validated against. If a future release changes the
  default path, only the step text needs revisiting.
- Needs egress to raw.githubusercontent.com, github.com releases, and the
  prometheus-community helm repo — standard Killercoda allowances.
- Root-only paths (`/root/*.txt`, `/usr/local/bin`) untouched; the harness adaptions
  cover local runs, and verify1 already falls back to `$HOME`.
