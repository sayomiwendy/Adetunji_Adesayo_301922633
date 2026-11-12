# Nigeria Data Protection Act 2023 (NDPA) - exam seat allocation

The database holds personal data of students: name, matric number, email, department, level, and a flag
`needs_accessible` (disability-related, treated as sensitive personal data).

| NDPA topic (section) | How this design responds |
|---|---|
| Principles of processing (s.24) | only data needed for seating is stored; purpose is exam administration |
| Lawful basis and consent (ss.25-26) | processing is part of the student's enrolment contract; the accessibility flag is stored only with the student's consent or request |
| Data subject rights (ss.34-38) | a student can ask for their record (`SELECT` by matric), correction (`UPDATE students`) and erasure/anonymisation after the retention period |
| Security (s.39) | role-based access (officers write, students read their own seat), TLS in transit, encrypted backups, audit trail in `seatings` (status, assigned_at, cancelled_at) |
| Breach notification (s.40) | breach register and notification to the NDPC within 72 hours |
| Cross-border transfer (ss.41-43) | a backup copy in a second region is a transfer: use a country with adequate protection or contractual safeguards |

Practical controls in the schema: `needs_accessible` is only used by the accessible-seat trigger and is left out
of the MongoDB reporting copy's public views; matric numbers are the only identifier shown on printed rosters.
