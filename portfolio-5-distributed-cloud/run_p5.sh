#!/usr/bin/env bash
# Portfolio 5 runner. Run from inside portfolio-5-distributed-cloud/ (after P1).
set -euo pipefail
echo "# P5 - Distributed databases and cloud"
echo ">>> [1/3] partitioning"
psql -X -d exam_db -f partitioning/01_partition_and_verify.sql 2>&1 | tee partition_output.log
echo ">>> [2/3] streaming replica"
bash replication/01_setup_replica.sh 2>&1 | tee replication_output.log
echo ">>> [3/3] replication demo (primary 5432, replica 55432)"
bash replication/02_demo_replication.sh 2>&1 | tee -a replication_output.log
echo "# P5 done. Evidence: partition_output.log and replication_output.log"
