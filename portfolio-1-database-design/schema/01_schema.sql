-- Portfolio 1 - Schema. Case study: Miva Open University Exam Seat Allocation.
-- Tables: exam_halls, seats, courses, students, registrations, exam_slots,
--         exam_papers, seatings (fact table).
DROP TABLE IF EXISTS seatings       CASCADE;
DROP TABLE IF EXISTS exam_papers    CASCADE;
DROP TABLE IF EXISTS exam_slots     CASCADE;
DROP TABLE IF EXISTS registrations  CASCADE;
DROP TABLE IF EXISTS students       CASCADE;
DROP TABLE IF EXISTS courses        CASCADE;
DROP TABLE IF EXISTS seats          CASCADE;
DROP TABLE IF EXISTS exam_halls     CASCADE;

CREATE TABLE exam_halls (
    hall_id     SERIAL PRIMARY KEY,
    hall_name   VARCHAR(80) NOT NULL UNIQUE,
    building    VARCHAR(80) NOT NULL,
    exam_mode   VARCHAR(5)  NOT NULL CHECK (exam_mode IN ('CBT','PAPER'))
);

CREATE TABLE seats (
    seat_id       SERIAL PRIMARY KEY,
    hall_id       INTEGER NOT NULL REFERENCES exam_halls(hall_id) ON DELETE CASCADE,
    seat_code     VARCHAR(10) NOT NULL,
    is_accessible BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (hall_id, seat_code)
);

CREATE TABLE courses (
    course_code VARCHAR(10) PRIMARY KEY,
    title       VARCHAR(120) NOT NULL,
    department  VARCHAR(60)  NOT NULL,
    exam_mode   VARCHAR(5)   NOT NULL CHECK (exam_mode IN ('CBT','PAPER')),
    timetable_no SMALLINT    NOT NULL UNIQUE,   -- position in the exam timetable plan
    CONSTRAINT chk_course_code CHECK (course_code ~ '^[A-Z]{3} [0-9]{3}$')
);

CREATE TABLE students (
    student_id        SERIAL PRIMARY KEY,
    matric_number     VARCHAR(20)  NOT NULL UNIQUE,
    full_name         VARCHAR(120) NOT NULL,
    email             VARCHAR(120) NOT NULL UNIQUE,
    department        VARCHAR(60)  NOT NULL,
    level             INTEGER      NOT NULL CHECK (level IN (100,200,300,400)),
    needs_accessible  BOOLEAN      NOT NULL DEFAULT false
);

CREATE TABLE registrations (
    student_id  INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    course_code VARCHAR(10) NOT NULL REFERENCES courses(course_code),
    semester    VARCHAR(12) NOT NULL,
    PRIMARY KEY (student_id, course_code, semester),
    CONSTRAINT chk_reg_semester CHECK (semester ~ '^\d{4}/\d{4}-S[12]$')
);

CREATE TABLE exam_slots (
    slot_id   SERIAL PRIMARY KEY,
    semester  VARCHAR(12) NOT NULL,
    slot_date DATE        NOT NULL,
    period    VARCHAR(9)  NOT NULL CHECK (period IN ('MORNING','AFTERNOON')),
    UNIQUE (slot_date, period),
    CONSTRAINT chk_slot_semester CHECK (semester ~ '^\d{4}/\d{4}-S[12]$')
);

-- one course is examined in one slot per semester
CREATE TABLE exam_papers (
    paper_id    SERIAL PRIMARY KEY,
    course_code VARCHAR(10) NOT NULL REFERENCES courses(course_code),
    slot_id     INTEGER     NOT NULL REFERENCES exam_slots(slot_id),
    UNIQUE (course_code, slot_id),
    UNIQUE (paper_id, slot_id)          -- lets seatings carry slot_id with a real FK
);

CREATE TABLE seatings (
    seating_id   BIGSERIAL PRIMARY KEY,
    student_id   INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    seat_id      INTEGER NOT NULL REFERENCES seats(seat_id),
    paper_id     INTEGER NOT NULL,
    slot_id      INTEGER NOT NULL,
    status       VARCHAR(10) NOT NULL DEFAULT 'ASSIGNED'
                 CHECK (status IN ('ASSIGNED','SAT','ABSENT','CANCELLED')),
    assigned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    cancelled_at TIMESTAMPTZ,
    FOREIGN KEY (paper_id, slot_id) REFERENCES exam_papers(paper_id, slot_id),
    CONSTRAINT chk_cancel_invariant CHECK ((status = 'CANCELLED') = (cancelled_at IS NOT NULL))
);

-- Active = ASSIGNED or SAT. These two indexes are the structural guarantee.
CREATE UNIQUE INDEX uniq_active_seat_per_slot
    ON seatings (seat_id, slot_id)    WHERE status IN ('ASSIGNED','SAT');
CREATE UNIQUE INDEX uniq_active_student_per_slot
    ON seatings (student_id, slot_id) WHERE status IN ('ASSIGNED','SAT');

COMMENT ON TABLE seatings IS 'Student <-> seat <-> exam paper. Active rows are ASSIGNED or SAT.';
