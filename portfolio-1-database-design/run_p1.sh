#!/usr/bin/env bash
# Portfolio 1 runner. Run from inside portfolio-1-database-design/
set -euo pipefail
DB_NAME="exam_db"
PSQL="psql -v ON_ERROR_STOP=1 -X -e"
echo "# P1 - Database Design: Miva Exam Seat Allocation"
psql -v ON_ERROR_STOP=1 -X -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};"
psql -v ON_ERROR_STOP=1 -X -d postgres -c "CREATE DATABASE ${DB_NAME};"
psql -X -d postgres -c "ALTER DATABASE ${DB_NAME} SET timezone TO 'Africa/Lagos';"
for f in schema/01_schema.sql schema/02_triggers.sql seed/03_seed.sql seed/04_bulk_generate.sql; do
  echo ">>> $f"; ${PSQL} -d "${DB_NAME}" -f "$f"
done
echo ">>> tests/05_constraint_tests.sql (8 tests, 7 must be rejected, 1 control must succeed)"
psql -X -d "${DB_NAME}" -f tests/05_constraint_tests.sql
echo "# P1 done"
