#!/bin/bash
[ "$(cat /root/cheapest.txt 2>/dev/null | tr -d '[:space:]')" = "api-alpha" ] || exit 1
[ "$(cat /root/expensive.txt 2>/dev/null | tr -d '[:space:]')" = "api-gamma" ] || exit 1
exit 0
