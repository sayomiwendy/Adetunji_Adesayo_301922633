#!/usr/bin/env bash
# Portfolio 2 runner. Run from inside portfolio-2-query-optimisation/ (after P1).
set -euo pipefail
DB_NAME="exam_db"
mkdir -p results
N=$(psql -X -At -d "$DB_NAME" -c "SELECT COUNT(*) FROM seatings")
echo "seatings rows: $N"; [ "$N" -ge 50000 ] || { echo "run P1 first"; exit 1; }
# fair, re-runnable: start with none of the P2 indexes
psql -X -q -d "$DB_NAME" -c "DROP INDEX IF EXISTS idx_seat_student_time, idx_seat_slot, idx_seat_paper;" -c "ANALYZE seatings;"
echo ">>> BEFORE indexes";  psql -X -d "$DB_NAME" -f queries/queries.sql > results/before_indexes.txt
echo ">>> create indexes";  psql -X -d "$DB_NAME" -f queries/02_create_indexes.sql | tee results/index_creation.txt
echo ">>> AFTER indexes";   psql -X -d "$DB_NAME" -f queries/queries.sql > results/after_indexes.txt
summ () { awk '/^--- Q/{q=$0} /Scan on (seatings|exam_papers)/{ if (match($0,/(Seq Scan|Index Only Scan|Index Scan|Bitmap Heap Scan) on (seatings|exam_papers)/)) {sc=sc (sc?"; ":"") substr($0,RSTART,RLENGTH)} } /Execution Time/{printf "%s\n    %s ms | %s\n", q, $3, sc; sc=""}' "$1"; }
{ echo "=== BEFORE indexes ==="; summ results/before_indexes.txt
  echo; echo "=== AFTER indexes ==="; summ results/after_indexes.txt; } | tee results/explain_summary.txt
echo "# P2 done. Real numbers are in results/explain_summary.txt"
