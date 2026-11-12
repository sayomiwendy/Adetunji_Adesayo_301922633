-- P3 - transaction-safe functions. Race-fix technique used here: pg_advisory_xact_lock
-- (a lock on "slot + exam mode" so two sessions cannot pick the same free seat).

CREATE OR REPLACE FUNCTION seat_first_free(p_student INTEGER, p_paper INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_slot  INTEGER;
    v_mode  VARCHAR(5);
    v_needs BOOLEAN;
    v_seat  INTEGER;
BEGIN
    SELECT p.slot_id, c.exam_mode INTO v_slot, v_mode
    FROM exam_papers p JOIN courses c ON c.course_code = p.course_code WHERE p.paper_id = p_paper;
    IF v_slot IS NULL THEN RAISE EXCEPTION 'Paper % does not exist', p_paper; END IF;
    SELECT needs_accessible INTO v_needs FROM students WHERE student_id = p_student;

    -- everyone seating into this slot+mode queues here until the holder commits
    PERFORM pg_advisory_xact_lock(hashtext('seat:' || v_slot || ':' || v_mode));

    SELECT s.seat_id INTO v_seat
    FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
    WHERE h.exam_mode = v_mode
      AND NOT EXISTS (SELECT 1 FROM seatings a WHERE a.seat_id = s.seat_id AND a.slot_id = v_slot
                      AND a.status IN ('ASSIGNED','SAT'))
    ORDER BY (CASE WHEN v_needs THEN NOT s.is_accessible ELSE s.is_accessible END), s.seat_id
    LIMIT 1;
    IF v_seat IS NULL THEN RAISE EXCEPTION 'No free % seat in slot %', v_mode, v_slot; END IF;

    INSERT INTO seatings (student_id, seat_id, paper_id, slot_id)
    VALUES (p_student, v_seat, p_paper, v_slot);
    RETURN v_seat;
END $$;

CREATE OR REPLACE FUNCTION cancel_seating(p_student INTEGER, p_slot INTEGER)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_n INTEGER;
BEGIN
    UPDATE seatings SET status = 'CANCELLED', cancelled_at = now()
    WHERE student_id = p_student AND slot_id = p_slot AND status IN ('ASSIGNED','SAT');
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END $$;

SELECT proname AS function_name FROM pg_proc WHERE proname IN ('seat_first_free','cancel_seating') ORDER BY 1;
