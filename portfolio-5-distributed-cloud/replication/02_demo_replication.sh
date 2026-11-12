#!/usr/bin/env bash
# P5 - ONE script that talks to both servers and prints labelled real output.
set -uo pipefail
P="psql -X -At -d exam_db"                      # primary (default socket, port 5432)
R="psql -X -At -h /tmp -p 55432 -d exam_db"     # replica (port 55432)
echo "=== 1. Who is who ==="
echo "primary : port $($P -c 'SHOW port'), in recovery = $($P -c 'SELECT pg_is_in_recovery()')"
echo "replica : port $($R -c 'SHOW port'), in recovery = $($R -c 'SELECT pg_is_in_recovery()')"

echo; echo "=== 2. A write on the REPLICA must be rejected ==="
$R -c "INSERT INTO exam_halls (hall_name, building, exam_mode) VALUES ('Should Fail','X','CBT')" 2>&1 || true

echo; echo "=== 3. Insert on the PRIMARY ==="
$P -c "INSERT INTO exam_halls (hall_name, building, exam_mode) VALUES ('Replication Test Hall','Demo Block','CBT') ON CONFLICT DO NOTHING"
echo "primary count of that hall: $($P -c "SELECT COUNT(*) FROM exam_halls WHERE hall_name='Replication Test Hall'")"

echo; echo "=== 4. The row arrives on the REPLICA ==="
for i in $(seq 1 20); do
  N=$($R -c "SELECT COUNT(*) FROM exam_halls WHERE hall_name='Replication Test Hall'")
  [ "$N" = "1" ] && break; sleep 0.5
done
echo "replica count of that hall: $N (after ~$((i/2)) s)"

echo; echo "=== 5. Replication status (primary side) ==="
psql -X -d exam_db -c "SELECT application_name, state, sync_state, sent_lsn, replay_lsn, (sent_lsn = replay_lsn) AS caught_up FROM pg_stat_replication"
echo "=== replica side ==="
psql -X -h /tmp -p 55432 -d exam_db -c "SELECT pg_last_wal_replay_lsn() AS replayed_up_to, pg_is_in_recovery() AS in_recovery"

echo; echo "=== 6. Same data on both: seatings count ==="
echo "primary: $($P -c 'SELECT COUNT(*) FROM seatings')   replica: $($R -c 'SELECT COUNT(*) FROM seatings')"

echo; echo "=== 7. Clean up the test row (delete on primary, check replica) ==="
$P -c "DELETE FROM exam_halls WHERE hall_name='Replication Test Hall'"
for i in $(seq 1 20); do
  N=$($R -c "SELECT COUNT(*) FROM exam_halls WHERE hall_name='Replication Test Hall'")
  [ "$N" = "0" ] && break; sleep 0.5
done
echo "replica count after delete: $N"
