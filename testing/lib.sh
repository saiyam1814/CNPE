#!/bin/bash
# Shared helpers for scenario testing. Source this from solution scripts.
# run_cmd prints the command like a terminal session, then executes it.
# All output goes to stdout (the harness tees it into testing/outputs/NN/session.log).

run_cmd() {
  echo ""
  echo "$ $*"
  eval "$*"
  return $?
}

# run_cmd_expect_fail: for commands that MUST fail (admission denials etc.)
run_cmd_expect_fail() {
  echo ""
  echo "$ $*"
  if eval "$*"; then
    echo "!! expected failure but command succeeded"
    return 1
  else
    return 0
  fi
}

# Where "/root" files live: real /root on killercoda, $HOME on dev machines.
ROOTDIR=/root
[ -w /root ] 2>/dev/null || ROOTDIR="$HOME"
export ROOTDIR

# retry <times> <sleep> <cmd...>
retry() {
  local n=$1 s=$2; shift 2
  local i
  for i in $(seq 1 "$n"); do
    if eval "$*"; then return 0; fi
    sleep "$s"
  done
  return 1
}
