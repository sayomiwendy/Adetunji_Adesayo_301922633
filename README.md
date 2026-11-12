# MIT 8103 Advanced Database Systems - Portfolio

**Student:** [Surname Firstname]  
**Matric Number:** [Matric Number]  
**Programme:** Master of Information Technology, Miva Open University  
**Course:** MIT 8103 Advanced Database Systems  
**GitHub Repository:** [GitHub link]

## Case study: Exam Seat Allocation, Miva Open University Examinations Office

At the end of each semester the Examinations Office seats about 1,200 students for 36 courses in 12 exam slots
(6 days, morning and afternoon). Some papers are written (PAPER) and some are computer-based (CBT); the halls are
of the matching kind. A student can only sit a paper they registered for, never two papers in the same slot,
and a student who needs an accessible seat must be placed in one.

**Users:** exam officers (assign and move seats), invigilators (hall rosters), students (look up their seat).
**Rules enforced by the database:** (1) CBT paper -> CBT lab, written paper -> paper hall; (2) the student is
registered for the course in that semester; (3) one active seat per student per slot; (4) one active student per
seat per slot; (5) accessible-seat students get accessible seats; (6) cancelled seatings carry a cancel time.

| Portfolio | Folder | What it shows |
|---|---|---|
| P1 Design | `portfolio-1-database-design/` | ER diagram, 8 tables, triggers, 64,800 seatings, 8 constraint tests |
| P2 Query optimisation | `portfolio-2-query-optimisation/` | 6 queries before/after indexes with EXPLAIN ANALYZE |
| P3 Transactions | `portfolio-3-transactions-concurrency/` | COMMIT/ROLLBACK, race condition, advisory-lock fix, write skew, isolation, deadlock |
| P4 NoSQL | `portfolio-4-nosql/` | MongoDB collection with validator, aggregations, COLLSCAN to IXSCAN |
| P5 Distributed + cloud | `portfolio-5-distributed-cloud/` | semester partitions, streaming replica, cloud design, NDPA |

## How to run (GitHub Codespaces)
```
bash setup.sh 2>&1 | tee setup_output.log     # once
bash runall.sh                                # runs P1-P5, commits each, writes my_results.txt
```
Every portfolio saves its own output log next to its scripts (`pN_output.log`, `race_demos_output.log`,
`replication_output.log`). Nothing in this repository is simulated: the logs come from the runs.

## Technology
PostgreSQL 16, MongoDB 8, Python 3 with psycopg2, GitHub Codespaces (Ubuntu).
References are in `docs/REFERENCES.md`; AI use is declared in the documentation PDF and in `CHANGES.md`.
