#!/usr/bin/env bash
# light traffic through the ingress for dashboards
U=http://campusdesk.localhost:8088/api
end=$((SECONDS+${1:-240}))
cats=(HARDWARE SOFTWARE NETWORK ACCOUNT); pris=(LOW MEDIUM HIGH URGENT)
while [ $SECONDS -lt $end ]; do
  for i in 1 2 3 4 5; do curl -s -o /dev/null $U/tickets; curl -s -o /dev/null $U/tickets/stats; curl -s -o /dev/null $U/info; done
  curl -s -o /dev/null $U/tickets/999
  c=${cats[$((RANDOM%4))]}; p=${pris[$((RANDOM%4))]}
  [ $((RANDOM%4)) -eq 0 ] && curl -s -o /dev/null -X POST $U/tickets -H 'Content-Type: application/json' -d "{\"title\":\"Load test ticket $c\",\"category\":\"$c\",\"priority\":\"$p\",\"requester\":\"traffic.sh\"}"
  sleep 0.5
done
