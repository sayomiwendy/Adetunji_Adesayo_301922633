# Portfolio 5 - Distributed databases and cloud

- `partitioning/01_partition_and_verify.sql` - `seatings` becomes a RANGE-partitioned table on `slot_id`, one
  partition per semester plus a DEFAULT partition (must stay empty) and a partition for the next semester.
  It checks row counts before swapping tables, keeps the P1 UNIQUE rules (they include the partition key),
  re-creates the triggers, shows partition pruning in EXPLAIN, and demonstrates DETACH/ATTACH of the oldest
  semester. Re-running is safe. Honest note: with 64,800 rows the one-semester query takes about the same time
  with or without partitioning; the benefits here are pruning and cheap archiving, and they grow with data.
- `replication/` - builds a streaming replica (port 55432) with `pg_basebackup`, then one script shows who is
  primary, a write rejected on the replica, a row arriving from the primary, replication status and cleanup.
- `cloud/architecture.md` - cloud design with diagram and trade-offs. `cloud/ndpa_compliance.md` - NDPA 2023 mapping.

Run: `bash run_p5.sh 2>&1 | tee p5_output.log` (evidence: `partition_output.log`, `replication_output.log`)
