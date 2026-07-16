#!/bin/bash
[ -f /root/triage.txt ] || exit 1
grep -qi "quota" /root/triage.txt || exit 1
grep -qi "secret" /root/triage.txt || exit 1
grep -qi "pvc\|persistentvolumeclaim\|volume" /root/triage.txt || exit 1
exit 0
