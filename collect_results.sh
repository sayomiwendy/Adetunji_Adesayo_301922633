#!/usr/bin/env bash
# collect_results.sh - gathers the key real output of every portfolio into my_results.txt
cd "$(dirname "$(readlink -f "$0")")"
OUT=my_results.txt
sec () { echo; echo "================ $1 ================"; }
f () { [ -f "$1" ] && return 0 || { echo "(no $1 - this portfolio did not run)"; return 1; }; }
{
echo "My results - generated $(date '+%Y-%m-%d %H:%M %Z') on $(hostname)"
sec "P1 - design: row counts, audits, constraint tests"
L=portfolio-1-database-design/p1_output.log
if f $L; then
  grep -E "TOTAL SEATINGS|registrations \(must|^ (SAT|ABSENT|ASSIGNED|CANCELLED) +\||future slots|mode mismatch|not registered|needs accessible|PASS|FAIL" $L | grep -vE "^(SELECT|UNION|[[:space:]]+RAISE)"
  grep -E "^ (exam_halls|seats|courses|students|exam_slots|exam_papers|registrations) +\|" $L
fi
sec "P2 - before/after indexes (explain_summary.txt)"
f portfolio-2-query-optimisation/results/explain_summary.txt && cat portfolio-2-query-optimisation/results/explain_summary.txt
sec "P3 - COMMIT/ROLLBACK and six concurrency demos"
L=portfolio-3-transactions-concurrency/p3_output.log
if f $L; then grep -E "^=== |BEFORE|AFTER" $L | head -20; fi
f portfolio-3-transactions-concurrency/race_demos_output.log && cat portfolio-3-transactions-concurrency/race_demos_output.log
sec "P4 - MongoDB"
L=portfolio-4-nosql/p4_output.log
if f $L; then
  grep -E "BAD DOC|inserted|countDocuments|^Label|BEFORE \||AFTER \||documents in collection" $L
fi
sec "P5 - partitions and replica"
f portfolio-5-distributed-cloud/partition_output.log && grep -vE "^(CREATE|INSERT|DROP|ALTER|BEGIN|COMMIT|ANALYZE|DO|SET)" portfolio-5-distributed-cloud/partition_output.log
f portfolio-5-distributed-cloud/replication_output.log && cat portfolio-5-distributed-cloud/replication_output.log
} > "$OUT" 2>&1
echo "Wrote $OUT ($(wc -l < "$OUT") lines)"
