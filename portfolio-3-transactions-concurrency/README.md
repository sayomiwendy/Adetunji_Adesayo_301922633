# Portfolio 3 - Transactions and concurrency

| Part | File | What it demonstrates |
|---|---|---|
| Functions | `sql/01_functions.sql` | `seat_first_free()` (advisory-lock fix) and `cancel_seating()` |
| COMMIT / ROLLBACK | `sql/02_commit_rollback.sql` | moving a seat is atomic: an invalid move rolls back completely |
| 1 Bug | `race_demos.py` | check-then-insert with no guard double-books a seat (scratch table) |
| 2 UNIQUE net | `race_demos.py` | P1's partial UNIQUE index rejects the second booking (23505) |
| 3 Fix | `race_demos.py` | `pg_advisory_xact_lock` on slot+mode: second session waits and gets the next seat |
| 4 Write skew | `race_demos.py` | "hall holds at most N" breaks under READ COMMITTED, is caught under SERIALIZABLE (40001) |
| 5 Isolation | `race_demos.py` | non-repeatable read in READ COMMITTED, stable snapshot in REPEATABLE READ |
| 6 Deadlock | `race_demos.py` | opposite lock order -> 40P01; same order -> no deadlock |

`race_demos.py` opens two real database sessions (psycopg2 + threads) and prints labelled real output, so no
manual two-terminal copying is needed. It restores the test data at the end.

Run: `bash run_p3.sh 2>&1 | tee p3_output.log` (evidence: `race_demos_output.log`)
