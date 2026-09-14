docker ps -a --filter name=41o7 --format '{{.Names}} :: {{.Status}}'
echo '=== LOGS ==='
for c in $(docker ps -aq --filter name=41o7); do docker logs --tail 30 $c 2>&1; done
