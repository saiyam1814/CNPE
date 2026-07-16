#!/bin/bash
# Downloads the darwin equivalents of the CLIs the scenarios install on Linux.
# Only needed for local (macOS) testing; Killercoda gets them from each setup.sh.
set -euo pipefail

BIN="$(cd "$(dirname "$0")" && pwd)/bin"
mkdir -p "$BIN"

ARGO_WF_VERSION=v3.7.2
TKN_VERSION=0.45.0
ROLLOUTS_VERSION=v1.9.0
ISTIO_VERSION=1.30.2
ARGOCD_VERSION=v3.2.6

OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64; [ "$ARCH" = "aarch64" ] && ARCH=arm64

if [ ! -x "$BIN/argo" ]; then
  echo "installing argo $ARGO_WF_VERSION"
  curl -sL "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WF_VERSION}/argo-${OS}-${ARCH}.gz" | gunzip > "$BIN/argo"
  chmod +x "$BIN/argo"
fi

if [ ! -x "$BIN/tkn" ]; then
  echo "installing tkn $TKN_VERSION"
  curl -sL "https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_Darwin_all.tar.gz" | tar xz -C "$BIN" tkn
  chmod +x "$BIN/tkn"
fi

if [ ! -x "$BIN/kubectl-argo-rollouts" ]; then
  echo "installing kubectl-argo-rollouts $ROLLOUTS_VERSION"
  curl -sL -o "$BIN/kubectl-argo-rollouts" "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/kubectl-argo-rollouts-${OS}-${ARCH}"
  chmod +x "$BIN/kubectl-argo-rollouts"
fi

if [ ! -x "$BIN/istioctl" ]; then
  echo "installing istioctl $ISTIO_VERSION"
  curl -sL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istioctl-${ISTIO_VERSION}-osx-${ARCH}.tar.gz" | tar xz -C "$BIN" istioctl
  chmod +x "$BIN/istioctl"
fi

if [ ! -x "$BIN/argocd" ]; then
  echo "installing argocd $ARGOCD_VERSION"
  curl -sL -o "$BIN/argocd" "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-${OS}-${ARCH}"
  chmod +x "$BIN/argocd"
fi

LINKERD_VERSION=edge-26.6.3
if [ ! -x "$BIN/linkerd" ]; then
  echo "installing linkerd $LINKERD_VERSION"
  SUFFIX="$OS"
  [ "$OS" = "darwin" ] && [ "$ARCH" = "arm64" ] && SUFFIX="darwin-arm64"
  [ "$OS" = "linux" ] && SUFFIX="linux-${ARCH}"
  curl -sL -o "$BIN/linkerd" "https://github.com/linkerd/linkerd2/releases/download/${LINKERD_VERSION}/linkerd2-cli-${LINKERD_VERSION}-${SUFFIX}"
  chmod +x "$BIN/linkerd"
fi

if [ ! -x "$BIN/kubectl-cost" ]; then
  echo "installing kubectl-cost"
  KCOST_VERSION=$(curl -s https://api.github.com/repos/kubecost/kubectl-cost/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -sL "https://github.com/kubecost/kubectl-cost/releases/download/${KCOST_VERSION}/kubectl-cost-${OS}-${ARCH}.tar.gz" | tar xz -C "$BIN" || true
  chmod +x "$BIN/kubectl-cost" 2>/dev/null || true
fi

echo "CLIs ready in $BIN:"
ls -l "$BIN"
