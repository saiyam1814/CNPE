# 03-hpa-autoscaling — fixes

- **`cnpe/03-hpa-autoscaling/setup.sh`: replaced the GNU-sed in-place edit of the metrics-server manifest with `kubectl patch`.**
  - The original line was `sed -i 's/args:/args:\n        - --kubelet-insecure-tls/' /tmp/metrics-server.yaml`. That relies on two GNU-sed behaviors (`-i` without a suffix argument, and `\n` in the replacement), so on the macOS test machine BSD sed errored out (`sed: 1: "/tmp/metrics-server.yaml ...`) and metrics-server was deployed **without** `--kubelet-insecure-tls`. It then failed to scrape kubelets (`x509: cannot validate certificate ... doesn't contain any IP SANs`), the HPA stayed at `<unknown>`, and the solve script timed out waiting for metrics.
  - New approach: `kubectl apply` the stock manifest, then `kubectl -n kube-system patch deploy metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'`. This is portable (no sed dialect dependency) and produces the same end state on the Killercoda kubeadm cluster; the only difference is one immediate rolling update of the metrics-server deployment right after creation.

No other changes. Verify scripts untouched. Second run passed end-to-end in ~1m17s (HPA read metrics, load-gen drove CPU to 139%/60%, scaled 2→4 replicas, SuccessfulRescale recorded).
