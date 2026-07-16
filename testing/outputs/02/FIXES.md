No fixes needed.

Note: the first run failed in verify2 because a concurrent process created another
kind cluster (`cnpe-b`) mid-run, which switched the default kubeconfig's
current-context away from `kind-cnpe-a` between the solve script and verify.
No scenario file was at fault. Reran with a pinned `KUBECONFIG` for `kind-cnpe-a`
(after deleting the `storage-lab` namespace and `fast-iops` StorageClass) and all
checks passed.
