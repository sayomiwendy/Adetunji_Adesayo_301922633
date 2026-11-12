#!/usr/bin/env bash
# Portfolio 3 runner. Run from inside portfolio-3-transactions-concurrency/ (after P1).
set -euo pipefail
DB_NAME="exam_db"
echo "# P3 - Transactions and Concurrency"
echo ">>> [1/3] functions";            psql -X -d "$DB_NAME" -f sql/01_functions.sql
echo ">>> [2/3] COMMIT / ROLLBACK";    psql -X -d "$DB_NAME" -f sql/02_commit_rollback.sql
echo ">>> [3/3] six concurrency demos (two real sessions)"
python3 race_demos.py 2>&1 | tee race_demos_output.log
echo "# P3 done. Evidence: race_demos_output.log"
