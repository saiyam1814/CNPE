No fixes needed (no scenario/solution files changed).

Local-test-only note: the first run failed because scenario 02's setup.sh
`kubectl apply`s a StorageClass named `standard`, which on a kind cluster
collides with kind's built-in default SC of the same name and strips its
`storageclass.kubernetes.io/is-default-class: "true"` annotation. Scenario 19's
PVC `metrics-ui-data` intentionally omits `storageClassName` (relies on the
cluster default class), so it stayed Pending and `metrics-ui` never became
available. Restored the annotation on the shared kind cluster
(`kubectl annotate sc standard storageclass.kubernetes.io/is-default-class=true`)
and reran: all checks passed in ~15s.

This cannot happen on Killercoda: each scenario gets a fresh VM, and the
kubeadm image's default SC is `local-path`, which scenario 02 does not touch.
If you test 02 before 19 on a shared kind cluster again, re-apply that
annotation first.
