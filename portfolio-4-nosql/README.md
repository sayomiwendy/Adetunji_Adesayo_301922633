# Portfolio 4 - NoSQL (MongoDB)

One document per exam sitting (student, course, slot, hall and seat embedded together), exported from the P1
PostgreSQL data so names and IDs match (`pg_sittings.jsonl`, not committed).

- `01_create_collection.js` - `$jsonSchema` validator (`additionalProperties: false`, enums, patterns) and two
  bad documents that must be rejected.
- `02_seed_mongo.js` - loads about 64,800 documents.
- `03_aggregations.js` - attendance by department, sittings per hall, top courses by absentees.
- `04_index_demo.js` - for three queries, `executionStats` before and after an index: COLLSCAN examines every
  document, IXSCAN examines only the matches.

See `docs/sql_vs_nosql.md` for when to use which. Run: `bash run_p4.sh 2>&1 | tee p4_output.log`
