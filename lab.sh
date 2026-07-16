#!/bin/bash
# lab.sh - run the CNPE labs locally on a kind cluster, no Killercoda needed.
#
#   ./lab.sh cluster [--cni calico]   create the 'cnpe-lab' kind cluster
#   ./lab.sh list                     list all labs
#   ./lab.sh start <NN>               build lab NN's environment (installs its stack)
#   ./lab.sh task <NN>                print the lab instructions
#   ./lab.sh check <NN>               run the lab's verification (the CHECK button)
#   ./lab.sh solution <NN>            print the solutions
#   ./lab.sh reset [--cni calico]     delete + recreate the cluster (clean slate)
#   ./lab.sh destroy                  delete the cluster
#
# Notes:
#   - One lab at a time per cluster is the intended flow; 'reset' between labs.
#   - Lab 04 needs a NetworkPolicy-enforcing CNI: create the cluster with
#     './lab.sh cluster --cni calico'.
#   - macOS users: run ./testing/ensure-clis.sh once (istioctl, argo, tkn, ...).
#     On Linux, each lab's setup installs the CLIs it needs, like on Killercoda.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLUSTER=cnpe-lab
CALICO_VERSION=v3.32.1

die() { echo "ERROR: $*" >&2; exit 1; }

lab_dir() {
  local n
  n=$(printf "%02d" "$((10#$1))") 2>/dev/null || die "bad lab number: $1"
  local d
  d=$(ls -d "$HERE/cnpe/$n-"* 2>/dev/null | head -1)
  [ -n "$d" ] || die "no lab numbered $n (try: ./lab.sh list)"
  echo "$d"
}

ensure_context() {
  local ctx
  ctx=$(kubectl config current-context 2>/dev/null) || die "no kubectl context - run: ./lab.sh cluster"
  case "$ctx" in
    kind-$CLUSTER) ;;
    *) echo "note: current context is '$ctx' (not kind-$CLUSTER) - using it anyway" ;;
  esac
}

cmd_cluster() {
  local cni=default
  [ "${1:-}" = "--cni" ] && cni="${2:-}"
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    echo "cluster '$CLUSTER' already exists (./lab.sh reset for a clean slate)"
    return 0
  fi
  if [ "$cni" = "calico" ]; then
    cat <<EOF | kind create cluster --name "$CLUSTER" --wait 120s --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
EOF
    echo "==> installing Calico $CALICO_VERSION (NetworkPolicy enforcement)"
    kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"
    kubectl -n kube-system rollout status ds/calico-node --timeout=300s
  else
    kind create cluster --name "$CLUSTER" --wait 120s
    echo "note: kind's default CNI does not enforce NetworkPolicies (matters for lab 04)."
    echo "      for enforcement: ./lab.sh reset --cni calico"
  fi
  kubectl config use-context "kind-$CLUSTER" >/dev/null
  echo "==> cluster ready"
}

cmd_list() {
  echo "CNPE labs (./lab.sh start <NN>):"
  for d in "$HERE"/cnpe/[0-9][0-9]-*/; do
    local name title
    name=$(basename "$d")
    title=$(python3 -c "import json;print(json.load(open('$d/index.json'))['title'])" 2>/dev/null)
    printf "  %s  %s\n" "${name%%-*}" "$title"
  done
}

cmd_start() {
  local d; d=$(lab_dir "$1")
  ensure_context
  echo "==> building environment for $(basename "$d") (this installs the lab's stack - can take minutes)"
  local tmp; tmp=$(mktemp -d)
  # strip killercoda-isms; retarget /root and system paths for local runs
  sed -e 's|^exec >>/var/log/cnpe-setup.log 2>&1||' \
      -e 's|^export KUBECONFIG=/root/.kube/config||' \
      -e 's|^touch /tmp/.cnpe-setup-done|echo LAB_ENV_READY|' \
      -e "s|/root/|$HOME/|g" \
      "$d/setup.sh" > "$tmp/setup.sh"
  if [ "$(uname)" = "Darwin" ] || [ ! -w /usr/local/bin ]; then
    mkdir -p "$tmp/bin" "$tmp/opt"
    sed -i.bak -e "s|/usr/local/bin|$tmp/bin|g" -e "s| -C /opt| -C $tmp/opt|g" -e "s|/opt/istio|$tmp/opt/istio|g" "$tmp/setup.sh"
    export PATH="$HERE/testing/bin:$PATH"
  fi
  if bash "$tmp/setup.sh" 2>&1 | tee "$tmp/setup.log" | grep -E "LAB_ENV_READY|error|Error|failed" | tail -5 | grep -q LAB_ENV_READY; then
    echo "==> environment ready. Read the task:  ./lab.sh task ${1}"
  else
    echo "==> setup may have had issues - full log: $tmp/setup.log"
    tail -8 "$tmp/setup.log"
    return 1
  fi
}

render_md() {
  # strip killercoda markers so the markdown reads naturally in a terminal
  sed -E \
    -e 's/\{\{exec( interrupt)?\}\}//g' \
    -e 's/\{\{copy\}\}//g' \
    -e 's/\{\{TRAFFIC_HOST1_([0-9]+)\}\}/http:\/\/localhost:\1/g' \
    -e 's/<details><summary>(.*)<\/summary>/\n──── \1 ────/g' \
    -e 's/<\/details>//g' \
    -e 's/<br>//g' \
    "$1"
}

cmd_task() {
  local d; d=$(lab_dir "$1")
  echo "══════════════════════════════════════════════════════════════"
  render_md "$d/intro.md"
  local i=1
  for s in "$d"/step*.md; do
    echo ""
    echo "══════════════ STEP $i ══════════════"
    render_md "$s"
    i=$((i+1))
  done
  echo ""
  echo "(check your work: ./lab.sh check ${1} · stuck? ./lab.sh solution ${1})"
}

cmd_solution() {
  local d; d=$(lab_dir "$1")
  python3 - "$d" <<'PYEOF'
import re, sys, glob
d = sys.argv[1]
for f in sorted(glob.glob(d + "/step*.md")):
    text = open(f).read()
    blocks = re.findall(r"<details><summary>(✅[^<]*)</summary>(.*?)</details>", text, re.S)
    if blocks:
        print(f"\n════════ {f.split('/')[-1]} ════════")
        for title, body in blocks:
            body = re.sub(r"\{\{(exec( interrupt)?|copy)\}\}", "", body)
            print(f"\n──── {title.strip()} ────")
            print(body.strip())
PYEOF
}

cmd_check() {
  local d; d=$(lab_dir "$1")
  ensure_context
  local fail=0 i=1
  for v in "$d"/verify*.sh; do
    [ -f "$v" ] || continue
    if bash "$v" >/dev/null 2>&1; then
      echo "✅ step $i: PASS"
    else
      echo "❌ step $i: not yet - keep going (details: bash $v)"
      fail=1
    fi
    i=$((i+1))
  done
  [ "$fail" = 0 ] && echo "🎉 lab complete!"
  return $fail
}

cmd_reset() {
  kind delete cluster --name "$CLUSTER" 2>/dev/null || true
  cmd_cluster "$@"
}

cmd_destroy() {
  kind delete cluster --name "$CLUSTER"
}

case "${1:-}" in
  cluster)  shift; cmd_cluster "$@" ;;
  list)     cmd_list ;;
  start)    [ $# -ge 2 ] || die "usage: ./lab.sh start <NN>"; cmd_start "$2" ;;
  task)     [ $# -ge 2 ] || die "usage: ./lab.sh task <NN>"; cmd_task "$2" ;;
  check)    [ $# -ge 2 ] || die "usage: ./lab.sh check <NN>"; cmd_check "$2" ;;
  solution) [ $# -ge 2 ] || die "usage: ./lab.sh solution <NN>"; cmd_solution "$2" ;;
  reset)    shift; cmd_reset "$@" ;;
  destroy)  cmd_destroy ;;
  *) grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20 ;;
esac
