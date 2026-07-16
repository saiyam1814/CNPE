#!/bin/bash
# Usage: ./run-scenario.sh <scenario-dir-name> [--keep] [--no-setup]
# Runs a scenario end-to-end against the CURRENT kubectl context:
#   1. adapted setup.sh   2. solution script   3. all verify scripts
# Captures a session log under testing/outputs/<NN>/.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCEN="$1"; shift || true
NO_SETUP=0
for a in "$@"; do [ "$a" = "--no-setup" ] && NO_SETUP=1; done

DIR="$REPO/cnpe/$SCEN"
NUM="${SCEN%%-*}"
OUT="$REPO/testing/outputs/$NUM"
mkdir -p "$OUT"

# local (non-root) testing: darwin CLIs live in testing/bin; linux binaries the
# setup scripts download go to a throwaway dir instead of /usr/local/bin
if [ ! -w /usr/local/bin ] || [ "$(uname)" = "Darwin" ]; then
  export PATH="$REPO/testing/bin:$PATH"
  mkdir -p "$OUT/linux-bin" "$OUT/opt"
  REWRITE_BIN=1
else
  REWRITE_BIN=0
fi

[ -d "$DIR" ] || { echo "no such scenario: $DIR"; exit 2; }

echo "=== [$SCEN] context: $(kubectl config current-context) ==="

if [ "$NO_SETUP" = "0" ]; then
  echo "--- setup"
  # strip killercoda-only lines (log redirect, root kubeconfig); retarget /root to $HOME
  sed -e 's|^exec >>/var/log/cnpe-setup.log 2>&1||' \
      -e 's|^export KUBECONFIG=/root/.kube/config||' \
      -e 's|^touch /tmp/.cnpe-setup-done|echo SETUP_DONE|' \
      -e "s|/root/|$HOME/|g" \
      "$DIR/setup.sh" > "$OUT/setup.adapted.sh"
  # on dev machines, CLI downloads for linux are pointless - drop them to a scratch dir
  if [ "$REWRITE_BIN" = "1" ]; then
    sed -i '' -e "s|/usr/local/bin|$OUT/linux-bin|g" -e "s| -C /opt| -C $OUT/opt|g" -e "s|/opt/istio|$OUT/opt/istio|g" "$OUT/setup.adapted.sh" 2>/dev/null || \
    sed -i -e "s|/usr/local/bin|$OUT/linux-bin|g" -e "s| -C /opt| -C $OUT/opt|g" -e "s|/opt/istio|$OUT/opt/istio|g" "$OUT/setup.adapted.sh"
  fi
  if ! bash "$OUT/setup.adapted.sh" > "$OUT/setup.log" 2>&1; then
    echo "SETUP FAILED - tail of log:"; tail -20 "$OUT/setup.log"; exit 3
  fi
  grep -q SETUP_DONE "$OUT/setup.log" || { echo "setup did not reach the end"; tail -20 "$OUT/setup.log"; exit 3; }
  echo "setup ok"
fi

SOLVE="$REPO/testing/solutions/$NUM-solve.sh"
if [ -f "$SOLVE" ]; then
  echo "--- solution"
  if ! bash "$SOLVE" 2>&1 | tee "$OUT/session.log"; then
    echo "SOLUTION SCRIPT FAILED"; exit 4
  fi
fi

echo "--- verify"
FAIL=0
for v in "$DIR"/verify*.sh; do
  [ -f "$v" ] || continue
  if bash "$v"; then
    echo "PASS $(basename "$v")"
  else
    echo "FAIL $(basename "$v")"; FAIL=1
  fi
done

if [ "$FAIL" = "0" ]; then
  echo "=== [$SCEN] ALL CHECKS PASSED ==="
else
  echo "=== [$SCEN] FAILURES PRESENT ==="
fi
exit $FAIL
