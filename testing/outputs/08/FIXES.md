# 08-argo-rollouts-bluegreen

No fixes needed.

- PASS on kind-cnpe-c first attempt, wall time ~24s (argo-rollouts install reused from 07,
  nginx images already cached; rev1 Healthy, nginx:1.26 preview + Paused human gate,
  promote flips active service, legacy deploy scaled to 0).
- Cosmetic only: in the recorded session the `kubectl run qa --rm -i` curl output
  (`active: server: ...` / `preview: server: ...`) was swallowed by the attach race on
  fast pod exit; the command still exited 0 and verification does not depend on it.
