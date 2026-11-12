# Portfolio 2 - Query processing and optimisation

`queries/queries.sql` is run twice (before and after `queries/02_create_indexes.sql`) with
`EXPLAIN (ANALYZE, BUFFERS)`. `run_p2.sh` drops the P2 indexes first, so the run is fair and repeatable, and writes
`results/explain_summary.txt` (milliseconds and how `seatings` was read) from the real output.

| Query | Kind | Index that helps |
|---|---|---|
| Q1 one student's history | selective | `(student_id, assigned_at DESC)` |
| Q2 seat usage for one slot | selective | `(slot_id, status)` |
| Q3 absentees for one course | selective | `(paper_id, status)` |
| Q4 roster of one hall, one slot | selective | `(slot_id, status)` |
| Q5, Q6 whole-table reports | full scan on purpose | none: they read every row, so a Seq Scan is the correct plan |

Read the plans honestly: selective queries move from Seq Scan to index/bitmap scans; Q5 and Q6 stay Seq Scan
because an index cannot beat reading 100% of the table. Small run-to-run differences with an unchanged plan are noise.

Run: `bash run_p2.sh 2>&1 | tee p2_output.log`
