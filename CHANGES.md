# CHANGES - what Claude fixed and tested

Student: Yewande [surname] | Course: MIT 8103 | Original: hostel allocation project drafted by the student's AI tool.
Claude tested and fixed the work; the student runs it herself in her own Codespace.

## 1. Topic change (similarity)
The submitted project was a **hostel bed allocation** system (hostels, rooms, beds, gender match), the same
domain as another classmate's hostel allocation project. To keep the work clearly different it was re-angled to
**exam seat allocation** (halls, seats, courses, registrations, exam slots, papers, seatings) with different
tables, rules, data and names. All five portfolios and the file layout were kept.

## 2. Problems found in the original and how they were fixed

| # | File | Problem | Fix | Tested result |
|---|---|---|---|---|
| 1 | setup.sh | `sudo -u postgres` asks for a password in Codespaces; no pipefail; broken yarn apt source stops `apt-get update`; psycopg2 never installed | `runuser -u postgres`, `set -euo pipefail`, remove yarn.list, psycopg2 install with a fallback chain and a final import check | roles/db created, psycopg2 import verified in the Codespaces-like test |
| 2 | P1 seed | "Student 1..1000" names, one programme, 100 allocations only | realistic Nigerian names, 6 departments, 4 levels, 1,200 students | 1,200 students loaded |
| 3 | P1 bulk | all rows RELEASED, no current or future bookings, identical counts | 9 semesters, SAT/ABSENT history (about 3% absent) plus 7,200 ASSIGNED seatings for the next 12 slots | 64,800 seatings, audits show 0 violations |
| 4 | P1 tests | tests relied on seed rows that bulk data could change | each test builds its own situation from live data, plus a control that must succeed | 7 rejected for the intended reason, 1 control passes |
| 5 | P2 | query mix not designed to show where indexes help and where they do not, a redundant index on a primary key, no reset of indexes before the BEFORE run | 4 selective queries and 2 deliberate full scans; the runner drops the P2 indexes first and writes `explain_summary.txt` | Q1-Q4 move from Seq Scan to index/bitmap scans (about 3 ms to under 1.3 ms); Q5-Q6 stay Seq Scan (about 20-25 ms) and are explained |
| 6 | P3 | race demos needed pasting into two terminals by hand | `race_demos.py` runs six demos with two real sessions: bug, UNIQUE net, advisory-lock fix, write skew (40001), isolation, deadlock (40P01) | all six parts print the expected real result |
| 7 | P4 | (replaced to match the new case study) validator, aggregations and index demo rebuilt; index drops wrapped so a missing index cannot stop the demo | data exported from PostgreSQL so IDs match; 2 bad documents must be rejected | 2/2 rejected, COLLSCAN to IXSCAN on 3 queries (about 64,800 docs examined down to the matching 48-780) |
| 8 | P5 | (replaced to match the new case study) replica and partitioning had to be re-done for the new tables | one script builds the replica (fast checkpoint, config and hba handled) and one script shows primary vs replica; partitioning has a DEFAULT partition check and a re-run guard | replica streaming, write rejected on replica, row arrives, counts equal (64,800) |
| 9 | runner | pasted multi-line boxes break in chat apps | one `runall.sh` file: finds or re-unzips the kit, starts PostgreSQL and mongod, installs psycopg2, runs P1-P5, commits and pushes each, writes `my_results.txt` | full run about one minute in the test environment |

## 3. Things the student should know for the defence
- The partial UNIQUE indexes, not the triggers, are what stop double booking; a trigger cannot see another
  session's uncommitted row (P3 part 1 and 2 show this).
- Partitioning gives little speed-up on 64,800 rows; its value here is pruning and cheap archiving.
- The bulk load disables triggers for speed and then audits the same rules with SQL.
