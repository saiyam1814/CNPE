# CNPE Scenarios and Solutions

27 hands-on, exam-style labs for the **Certified Cloud Native Platform Engineer
(CNPE)** exam - run them free in the browser on Killercoda, or locally on kind.

- 🧪 **Interactive labs:** [killercoda.com/saiyampathak/course/cnpe](https://killercoda.com/saiyampathak/course/cnpe)
- 💻 **Local labs on kind:** `./lab.sh` (see below) - same tasks, same verification
- 📖 **Companion ebook** - *CNPE Scenarios and Solutions*: every lab as a full chapter
  with concepts, diagrams, real tested outputs, and exam tips. Published separately
  on Gumroad (link coming soon)
- ✅ **Everything tested:** every setup script, solution, and verification in this repo
  is exercised end-to-end on kind by `testing/run-scenario.sh`

## Repository layout

```
cnpe/                    Killercoda course (27 scenarios, one directory each)
  01-resourcequota-limitrange/
    index.json           scenario config (steps, verify, backend image)
    setup.sh             background environment build
    intro.md step*.md    exam-style task + tips + solution dropdowns
    verify*.sh           CHECK-button verification (exit 0 = pass)
  ...
testing/
  run-scenario.sh        run one scenario end-to-end against current kubectl context
  solutions/NN-solve.sh  scripted solutions (double as output capture for the book)
  outputs/NN/            captured session logs + per-scenario FIXES.md
  ensure-clis.sh         downloads darwin CLIs for local testing
```

## The 27 scenarios

Ordered by exam domain (weights from the official curriculum):

| Part | Domain | Scenarios |
|---|---|---|
| I | Platform Architecture & Infrastructure (15%) | 01 quota/limits · 02 PVCs · 03 HPA · 04 NetworkPolicy · 05 OpenCost |
| II | GitOps & Continuous Delivery (25%) | 06 Argo CD · 07 canary · 08 blue/green · 09–10 Argo Workflows · 11–12 Tekton |
| III | Platform APIs & Self-Service (25%) | 13 CRD · 14 Crossplane Composition · 15 Crossplane Claim |
| IV | Observability & Operations (20%) | 16 Grafana · 17 PrometheusRule · 18 Jaeger/OTel · 19 incident triage |
| V | Security & Policy (15%) | 20 RBAC · 21 PSS · 22 Gatekeeper · 23 Kyverno+Cosign · 24 Istio authz · 25 Trivy gate |
| VI | Bonus (curriculum completeness) | 26 Flagger canary · 27 Linkerd authorization |

## Doing the labs locally on kind (no Killercoda needed)

```bash
./lab.sh cluster              # create the cnpe-lab kind cluster
./lab.sh cluster --cni calico # ...with NetworkPolicy enforcement (needed for lab 04)
./lab.sh list                 # all 27 labs
./lab.sh start 07             # build lab 07's environment (installs its stack)
./lab.sh task 07              # read the exam-style task in your terminal
# ...solve it with kubectl...
./lab.sh check 07             # the CHECK button, locally
./lab.sh solution 07          # stuck? the full solution
./lab.sh reset                # clean slate between labs
```

macOS users: run `./testing/ensure-clis.sh` once for the darwin CLIs (istioctl, argo,
tkn, linkerd, ...). On Linux each lab's setup installs its own CLIs, exactly like on
Killercoda.

## CI-style testing of a scenario (setup + solution + verify)

```bash
kind create cluster --name cnpe
./testing/run-scenario.sh 01-resourcequota-limitrange
```

The harness adapts each `setup.sh` (Killercoda-isms stripped), runs the scripted
solution from `testing/solutions/`, then executes the scenario's own verify scripts - 
the same ones behind the Killercoda CHECK button.

## Publishing the Killercoda course

The live course is served from the `cnpe/` folder inside
[`saiyam1814/katacoda-scenarios`](https://github.com/saiyam1814/katacoda-scenarios)
(the repo linked to the [killercoda.com/saiyampathak](https://killercoda.com/saiyampathak)
profile). **This repo is the source of truth** - after changing anything under `cnpe/`,
publish with:

```bash
./sync-to-killercoda.sh              # lint, rsync into katacoda-scenarios, commit, push
./sync-to-killercoda.sh --dry-run    # preview what would change
```

The script refuses to run if the target repo ever gains a root `structure.json`
(which would hide every other scenario on the profile). Killercoda's GitHub webhook
picks up the push and updates the live course within a minute or two.

(The root `structure.json` in *this* repo only matters if you ever link this repo to a
Killercoda profile directly - it exposes `cnpe/` as the sole course and hides `testing/`.)

---

*The scenarios are original work inspired by the official CNCF CNPE curriculum. CNPE
is a certification of the Linux Foundation / CNCF.*
