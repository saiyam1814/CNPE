# 10-argo-workflows-edit-steps

Fixes applied:

- **Bug (would also fail on Killercoda):** the `deploy` and `wait-ready` templates used
  `command: [sh, -c]` with image `rancher/kubectl:v1.28.0`, but that image contains only
  `/bin/kubectl` — no shell on any architecture (verified by exporting the amd64 and arm64
  image filesystems). The workflow failed with
  `Error: failed to find name in PATH: exec: "sh": executable file not found in $PATH`.
- Changed those two templates to exec kubectl directly
  (`command: [kubectl]` + list-form args) in:
  - `cnpe/10-argo-workflows-edit-steps/setup.sh` (the pre-created `/root/release-checker.yaml`)
  - `cnpe/10-argo-workflows-edit-steps/step1.md` (tip + full solution blocks, plus a one-line
    note that the image has no shell)
  - `testing/solutions/10-solve.sh`
- The `test` template keeps `command: [sh, -c]` — it uses `busybox:1.36`, which has a shell.
- `verify1.sh` unchanged: it joins the container args with spaces and looks for
  `rollout status` + `checkout-api`, which the list-form args still satisfy.

Result: PASS on kind-cnpe-c, wall time ~34s (second run; first run failed as above).

## 2026-07-19 field report fix (thanks Vishal)
- The em-dash cleanup on 2026-07-17 accidentally collapsed the Argo steps
  double-dash syntax in step1.md ("- - name:" became "-  name:"), producing
  invalid YAML in the solution block (line-13 "mapping values are not allowed").
  setup.sh and verify were never affected. Restored and re-tested end-to-end
  (run passed; ALL CHECKS PASSED). Book chapter 10 had the same corruption, fixed.
