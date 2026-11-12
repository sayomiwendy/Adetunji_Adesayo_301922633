-- Portfolio 1 - Triggers: rules that span tables (cannot be CHECK/UNIQUE).
-- R1 hall mode must equal course mode (CBT paper -> CBT lab)
-- R2 student must be registered for the course in that paper's semester
-- R3 a student who needs an accessible seat must get one
-- They fire on INSERT and on UPDATE of the relevant columns, and only for active rows.

CREATE OR REPLACE FUNCTION trg_fn_seating_rules() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_course   VARCHAR(10);
    v_semester VARCHAR(12);
    v_cmode    VARCHAR(5);
    v_hmode    VARCHAR(5);
    v_access   BOOLEAN;
    v_needs    BOOLEAN;
BEGIN
    IF NEW.status NOT IN ('ASSIGNED','SAT') THEN
        RETURN NEW;                       -- history rows are not re-validated
    END IF;

    SELECT p.course_code, sl.semester, c.exam_mode
      INTO v_course, v_semester, v_cmode
    FROM exam_papers p
    JOIN exam_slots sl ON sl.slot_id = p.slot_id
    JOIN courses c     ON c.course_code = p.course_code
    WHERE p.paper_id = NEW.paper_id;

    SELECT h.exam_mode, s.is_accessible INTO v_hmode, v_access
    FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
    WHERE s.seat_id = NEW.seat_id;

    SELECT needs_accessible INTO v_needs FROM students WHERE student_id = NEW.student_id;

    IF v_hmode IS NULL OR v_needs IS NULL OR v_course IS NULL THEN
        RAISE EXCEPTION 'Unknown seat, student or paper (seat %, student %, paper %)',
            NEW.seat_id, NEW.student_id, NEW.paper_id USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF v_hmode <> v_cmode THEN
        RAISE EXCEPTION 'Mode mismatch: % is a % paper but seat % is in a % hall',
            v_course, v_cmode, NEW.seat_id, v_hmode USING ERRCODE = 'check_violation';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM registrations r
                   WHERE r.student_id = NEW.student_id
                     AND r.course_code = v_course AND r.semester = v_semester) THEN
        RAISE EXCEPTION 'Student % is not registered for % in %',
            NEW.student_id, v_course, v_semester USING ERRCODE = 'check_violation';
    END IF;

    IF v_needs AND NOT v_access THEN
        RAISE EXCEPTION 'Student % needs an accessible seat but seat % is not accessible',
            NEW.student_id, NEW.seat_id USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_seating_rules ON seatings;
CREATE TRIGGER trg_seating_rules
BEFORE INSERT OR UPDATE OF student_id, seat_id, paper_id, status ON seatings
FOR EACH ROW EXECUTE FUNCTION trg_fn_seating_rules();

-- Friendly messages for the two uniqueness rules (the partial UNIQUE indexes stay the real guarantee).
CREATE OR REPLACE FUNCTION trg_fn_one_seat_per_slot() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status IN ('ASSIGNED','SAT') THEN
        IF EXISTS (SELECT 1 FROM seatings a WHERE a.seat_id = NEW.seat_id AND a.slot_id = NEW.slot_id
                   AND a.status IN ('ASSIGNED','SAT') AND a.seating_id <> COALESCE(NEW.seating_id,-1)) THEN
            RAISE EXCEPTION 'Seat % is already taken in slot %', NEW.seat_id, NEW.slot_id
                USING ERRCODE = 'unique_violation';
        END IF;
        IF EXISTS (SELECT 1 FROM seatings a WHERE a.student_id = NEW.student_id AND a.slot_id = NEW.slot_id
                   AND a.status IN ('ASSIGNED','SAT') AND a.seating_id <> COALESCE(NEW.seating_id,-1)) THEN
            RAISE EXCEPTION 'Student % already has a paper in slot % (clash)', NEW.student_id, NEW.slot_id
                USING ERRCODE = 'unique_violation';
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_one_seat_per_slot ON seatings;
CREATE TRIGGER trg_one_seat_per_slot
BEFORE INSERT OR UPDATE OF student_id, seat_id, slot_id, status ON seatings
FOR EACH ROW EXECUTE FUNCTION trg_fn_one_seat_per_slot();

SELECT tgname AS trigger_name FROM pg_trigger
WHERE tgrelid = 'seatings'::regclass AND NOT tgisinternal ORDER BY 1;
