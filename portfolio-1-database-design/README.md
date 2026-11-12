# Portfolio 1 - Database design and modelling

Case study: Miva Exam Seat Allocation (see the main README).

## ER diagram
```mermaid
erDiagram
    direction LR
    EXAM_HALLS ||--o{ SEATS : has
    SEATS ||--o{ SEATINGS : "is used in"
    STUDENTS ||--o{ SEATINGS : sits
    STUDENTS ||--o{ REGISTRATIONS : registers
    COURSES ||--o{ REGISTRATIONS : "taken as"
    COURSES ||--o{ EXAM_PAPERS : "examined as"
    EXAM_SLOTS ||--o{ EXAM_PAPERS : schedules
    EXAM_PAPERS ||--o{ SEATINGS : "paper of"
    EXAM_HALLS { int hall_id PK
        string exam_mode "CBT or PAPER" }
    SEATS { int seat_id PK
        int hall_id FK
        bool is_accessible }
    STUDENTS { int student_id PK
        string matric_number UK
        bool needs_accessible }
    COURSES { string course_code PK
        string exam_mode }
    REGISTRATIONS { int student_id FK
        string course_code FK
        string semester }
    EXAM_SLOTS { int slot_id PK
        date slot_date
        string period }
    EXAM_PAPERS { int paper_id PK
        string course_code FK
        int slot_id FK }
    SEATINGS { bigint seating_id PK
        int student_id FK
        int seat_id FK
        int paper_id FK
        int slot_id FK
        string status }
```

## Design decisions
- **3NF:** halls, seats, courses, students, slots and papers each hold facts about one thing; registrations
  (student x course x semester) and seatings (student x seat x paper) are the many-to-many link tables.
- **Deliberate redundancy:** `seatings.slot_id` repeats the slot of its paper. A composite FK
  `(paper_id, slot_id) -> exam_papers` keeps it consistent, and it lets two partial UNIQUE indexes enforce
  "one seat per student per slot" and "one student per seat per slot" directly.
- **Triggers** (`schema/02_triggers.sql`) cover rules that span tables: mode match, registration, accessible seat.
  The partial UNIQUE indexes are the real guarantee against double booking; the triggers give clear messages.
- **Data:** 5 halls (860 seats), 36 courses, 1,200 students, 9 semesters (8 past + the current one whose 12 slots
  start tomorrow), 64,800 registrations and 64,800 seatings. Past seatings are SAT or ABSENT (about 3%),
  upcoming ones are ASSIGNED. The bulk load switches the triggers off for speed and then audits the same rules
  with SQL (all three audits must show 0 violations).
- **Tests** (`tests/05_constraint_tests.sql`): each test builds its situation from live data, tries one bad
  statement and checks it fails for the intended reason; T8 is a control that must succeed. Everything is rolled back.

Run: `bash run_p1.sh 2>&1 | tee p1_output.log`
