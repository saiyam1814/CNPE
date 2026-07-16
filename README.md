# CNPE Scenarios and Solutions

The hands-on companion for the **Certified Cloud Native Platform Engineer (CNPE)**
exam: an ebook with 25 exam-style scenarios plus a matching interactive
**Killercoda course** where every scenario runs on a real cluster with automated
verification.

- 📖 **Ebook:** `book/dist/` (HTML / PDF / EPUB — build with `book/build.sh`)
- 🧪 **Interactive labs:** [killercoda.com/saiyampathak/course/cnpe](https://killercoda.com/saiyampathak/course/cnpe)
- ✅ **Everything tested:** every setup script, solution, and verification in this repo
  is exercised end-to-end on kind by `testing/run-scenario.sh`

## Repository layout

```
cnpe/                    Killercoda course (25 scenarios, one directory each)
  01-resourcequota-limitrange/
    index.json           scenario config (steps, verify, backend image)
    setup.sh             background environment build
    intro.md step*.md    exam-style task + tips + solution dropdowns
    verify*.sh           CHECK-button verification (exit 0 = pass)
  ...
book/
  src/                   chapter markdown (front matter, 5 parts, 25 chapters, appendices)
  images/                Excalidraw-style SVG diagrams (generated)
  tools/                 diagram generator (xkd.py, diagrams.py) + preprocess.py
  styles/                book.css + Excalifont
  build.sh               builds HTML, PDF (headless Chrome), EPUB into book/dist/
testing/
  run-scenario.sh        run one scenario end-to-end against current kubectl context
  solutions/NN-solve.sh  scripted solutions (double as output capture for the book)
  outputs/NN/            captured session logs + per-scenario FIXES.md
  ensure-clis.sh         downloads darwin CLIs for local testing
```

## The 25 scenarios

Ordered by exam domain (weights from the official curriculum):

| Part | Domain | Scenarios |
|---|---|---|
| I | Platform Architecture & Infrastructure (15%) | 01 quota/limits · 02 PVCs · 03 HPA · 04 NetworkPolicy · 05 OpenCost |
| II | GitOps & Continuous Delivery (25%) | 06 Argo CD · 07 canary · 08 blue/green · 09–10 Argo Workflows · 11–12 Tekton |
| III | Platform APIs & Self-Service (25%) | 13 CRD · 14 Crossplane Composition · 15 Crossplane Claim |
| IV | Observability & Operations (20%) | 16 Grafana · 17 PrometheusRule · 18 Jaeger/OTel · 19 incident triage |
| V | Security & Policy (15%) | 20 RBAC · 21 PSS · 22 Gatekeeper · 23 Kyverno+Cosign · 24 Istio authz · 25 Trivy gate |

## Testing a scenario locally

```bash
kind create cluster --name cnpe
./testing/ensure-clis.sh                 # once, downloads darwin CLIs
./testing/run-scenario.sh 01-resourcequota-limitrange
```

The harness adapts each `setup.sh` (Killercoda-isms stripped), runs the scripted
solution, then executes the scenario's own verify scripts — the same ones behind the
Killercoda CHECK button.

## Building the book

```bash
./book/build.sh    # needs pandoc + Chrome; outputs to book/dist/
```

Diagrams are generated (`python3 book/tools/diagrams.py`) in a hand-drawn, light-theme
Excalidraw style and inlined into the HTML/EPUB so the Excalifont typography survives
every format.

## Publishing the Killercoda course

Add this repository to your [Killercoda creator profile](https://killercoda.com/creators);
the root `structure.json` exposes only `cnpe/` as a course. Every push updates the live
scenarios.

---

*The scenarios are original work inspired by the official CNCF CNPE curriculum. CNPE
is a certification of the Linux Foundation / CNCF.*
