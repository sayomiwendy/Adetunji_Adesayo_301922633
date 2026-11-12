#!/usr/bin/env bash
# Portfolio 4 runner. Run from inside portfolio-4-nosql/ (after P1). Needs mongod running on 127.0.0.1:27017.
set -euo pipefail
cd "$(dirname "$0")"
if ! mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; then
  echo "mongod is not running - starting it"
  sudo mkdir -p /data/db /var/log/mongodb; sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
  sudo runuser -u mongodb -- /usr/bin/mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
  for i in $(seq 1 20); do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 && break; sleep 1; done
fi
echo "# P4 - NoSQL (MongoDB)"
echo ">>> export sittings from PostgreSQL"
psql -X -At -d exam_db -c "
SELECT json_build_object('seatingId', a.seating_id, 'matric', st.matric_number, 'studentName', st.full_name,
  'department', st.department, 'level', st.level, 'needsAccessible', st.needs_accessible,
  'courseCode', c.course_code, 'courseTitle', c.title, 'examMode', c.exam_mode, 'semester', sl.semester,
  'slotDate', sl.slot_date, 'period', sl.period, 'hall', h.hall_name, 'seatCode', s.seat_code, 'status', a.status)
FROM seatings a JOIN students st ON st.student_id = a.student_id
JOIN exam_papers p ON p.paper_id = a.paper_id JOIN courses c ON c.course_code = p.course_code
JOIN exam_slots sl ON sl.slot_id = a.slot_id JOIN seats s ON s.seat_id = a.seat_id
JOIN exam_halls h ON h.hall_id = s.hall_id" > pg_sittings.jsonl
wc -l pg_sittings.jsonl
for f in 01_create_collection 02_seed_mongo 03_aggregations 04_index_demo; do
  echo ">>> scripts/$f.js"; mongosh --quiet --file scripts/$f.js
done
echo "# P4 done"
