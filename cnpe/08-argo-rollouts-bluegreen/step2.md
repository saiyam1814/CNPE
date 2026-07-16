# Release green, verify on preview, promote

Ship the new version into the **preview** lane:

```bash
kubectl argo rollouts set image catalog catalog=argoproj/rollouts-demo:green -n shop-core
```{{exec}}

Look at the state — the Rollout is now **Paused**, blue still serves customers,
green runs behind the preview Service:

```plain
kubectl argo rollouts get rollout catalog -n shop-core
```{{exec}}

Prove the two lanes serve different versions (the demo app reports its color):

```bash
kubectl -n shop-core run qa --rm -i --restart=Never --image=curlimages/curl:8.9.1 -- \
  sh -c 'echo -n "active:  "; curl -s catalog-active.shop-core.svc/color; echo; echo -n "preview: "; curl -s catalog-preview.shop-core.svc/color; echo'
```{{exec}}

QA signs off — promote:

```bash
kubectl argo rollouts promote catalog -n shop-core
```{{exec}}

Watch until the green ReplicaSet is `stable,active` — then run the curl probe again;
both lanes now answer `green`. Finally, retire the legacy Deployment:

```bash
kubectl argo rollouts get rollout catalog -n shop-core
kubectl -n shop-core scale deploy catalog --replicas=0
```{{exec}}

<details><summary>✦ What did promote actually do?</summary>

It flipped the `rollouts-pod-template-hash` selector on **catalog-active** to the green
ReplicaSet's hash. Nothing was restarted — that is why blue/green switchovers are
instant, and why the blue ReplicaSet sticks around (scaled up for
`scaleDownDelaySeconds`, default 30s) in case you need `kubectl argo rollouts undo`.

</details>
