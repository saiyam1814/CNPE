#!/bin/bash
source "$(dirname "$0")/../lib.sh"
set -e

run_cmd "kubectl -n build-room create serviceaccount ci-bot"
run_cmd "kubectl -n build-room create role ci-bot --verb=get,list,watch,create,update,patch --resource=deployments.apps,configmaps"
run_cmd "kubectl -n build-room create rolebinding ci-bot --role=ci-bot --serviceaccount=build-room:ci-bot"

run_cmd "kubectl -n build-room describe role ci-bot"

AS="--as=system:serviceaccount:build-room:ci-bot"
run_cmd "kubectl auth can-i create deployments -n build-room $AS"
run_cmd "kubectl auth can-i delete deployments -n build-room $AS || true"
run_cmd "kubectl auth can-i create deployments -n default $AS || true"
run_cmd "kubectl auth can-i get secrets -n build-room $AS || true"

run_cmd "kubectl auth can-i --list -n build-room $AS | tee $ROOTDIR/ci-bot-perms.txt"
