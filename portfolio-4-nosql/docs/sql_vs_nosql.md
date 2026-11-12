# SQL vs NoSQL for exam seating

| Question | PostgreSQL (P1-P3) | MongoDB (P4) |
|---|---|---|
| Shape | 8 normalised tables, FK and CHECK rules | one denormalised document per sitting |
| Rules (mode match, registration, accessible seat) | triggers + partial UNIQUE indexes, enforced by the database | only the schema validator; cross-collection rules must live in application code |
| Double-booking guard | partial UNIQUE index on (seat, slot) | a unique index can do it, but there is no cross-document transaction logic like seat_first_free() |
| Reading a hall roster / attendance report | joins over 5 tables | one collection scan or one indexed find, no joins |
| Change a student's name | one UPDATE | every embedded copy must be updated |

Use PostgreSQL as the system of record (it enforces the rules). Use MongoDB as a read-optimised copy for dashboards and reports; it is rebuilt from PostgreSQL by `run_p4.sh`.
