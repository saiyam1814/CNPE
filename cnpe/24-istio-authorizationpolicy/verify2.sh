#!/bin/bash
# storefront allowed (bounded retry: envoy config pushes can briefly interrupt
# the connection right after the policy lands; the assertion itself is unchanged)
OK=0
for _ in 1 2 3 4; do
  OUT=$(kubectl -n web exec storefront -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname 2>/dev/null)
  echo "$OUT" | grep -q "checkout" && { OK=1; break; }
  sleep 5
done
[ "$OK" = "1" ] || exit 1

# reporting denied (RBAC message or empty/non-200)
OUT2=$(kubectl -n batch exec reporting -- curl -s --max-time 5 http://checkout.payments.svc:8080/hostname 2>/dev/null)
echo "$OUT2" | grep -qi "denied" || { echo "$OUT2" | grep -q "checkout" && exit 1; }

exit 0
