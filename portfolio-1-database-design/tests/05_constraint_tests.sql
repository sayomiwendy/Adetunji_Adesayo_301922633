-- Portfolio 1 - Constraint tests. Each test builds its own situation from live data,
-- tries ONE bad statement and checks it fails for the intended reason (PASS line).
-- The last test is a control that must SUCCEED. Every attempt is rolled back.
\set ON_ERROR_STOP off
CREATE OR REPLACE FUNCTION pg_temp.expect_fail(tname text, want text, q text) RETURNS text
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE q;
    RAISE EXCEPTION USING ERRCODE = 'ZZ001', MESSAGE = 'no error was raised';
EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = want THEN RETURN 'PASS  ' || tname || '  ->  ' || SQLERRM;
    ELSE RETURN 'FAIL  ' || tname || '  (got ' || SQLSTATE || ': ' || SQLERRM || ')'; END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.expect_ok(tname text, q text) RETURNS text
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE q;
    RAISE EXCEPTION USING ERRCODE = 'ZZ001', MESSAGE = 'rolled back on purpose';
EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'ZZ001' THEN RETURN 'PASS  ' || tname || '  ->  statement succeeded';
    ELSE RETURN 'FAIL  ' || tname || '  (' || SQLSTATE || ': ' || SQLERRM || ')'; END IF;
END $$;

-- A: a regular student with an ASSIGNED seating in a future slot
SELECT a.seating_id AS a_id, a.student_id AS a_st, a.seat_id AS a_seat, a.paper_id AS a_paper,
       a.slot_id AS a_slot, h.exam_mode AS a_mode
FROM seatings a JOIN students st ON st.student_id = a.student_id
JOIN seats s ON s.seat_id = a.seat_id JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE a.status = 'ASSIGNED' AND NOT st.needs_accessible
ORDER BY a.slot_id, a.seating_id LIMIT 1 \gset

-- B: another active seating in the same slot and mode
SELECT b.student_id AS b_st, b.paper_id AS b_paper, b.seat_id AS b_seat, b.seating_id AS b_id
FROM seatings b JOIN seats s ON s.seat_id = b.seat_id JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE b.slot_id = :a_slot AND b.status = 'ASSIGNED' AND h.exam_mode = :'a_mode' AND b.seating_id <> :a_id
ORDER BY b.seating_id LIMIT 1 \gset

-- free ordinary seats in that slot: same mode / other mode
SELECT s.seat_id AS free_same FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE h.exam_mode = :'a_mode' AND NOT s.is_accessible
  AND NOT EXISTS (SELECT 1 FROM seatings x WHERE x.seat_id = s.seat_id AND x.slot_id = :a_slot
                  AND x.status IN ('ASSIGNED','SAT'))
ORDER BY s.seat_id LIMIT 1 \gset
SELECT s.seat_id AS free_other FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE h.exam_mode <> :'a_mode' AND NOT s.is_accessible
  AND NOT EXISTS (SELECT 1 FROM seatings x WHERE x.seat_id = s.seat_id AND x.slot_id = :a_slot
                  AND x.status IN ('ASSIGNED','SAT'))
ORDER BY s.seat_id LIMIT 1 \gset

-- C: a student with no paper in that slot (so not registered for its courses)
SELECT st.student_id AS c_st FROM students st
WHERE NOT EXISTS (SELECT 1 FROM seatings x WHERE x.student_id = st.student_id AND x.slot_id = :a_slot
                  AND x.status IN ('ASSIGNED','SAT')) AND NOT st.needs_accessible
ORDER BY st.student_id LIMIT 1 \gset

-- N: a student who needs an accessible seat, with an ASSIGNED seating
SELECT n.student_id AS n_st, n.paper_id AS n_paper, n.slot_id AS n_slot, n.seating_id AS n_id, h.exam_mode AS n_mode
FROM seatings n JOIN students st ON st.student_id = n.student_id
JOIN seats s ON s.seat_id = n.seat_id JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE n.status = 'ASSIGNED' AND st.needs_accessible ORDER BY n.seating_id LIMIT 1 \gset
SELECT s.seat_id AS n_free FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
WHERE h.exam_mode = :'n_mode' AND NOT s.is_accessible
  AND NOT EXISTS (SELECT 1 FROM seatings x WHERE x.seat_id = s.seat_id AND x.slot_id = :n_slot
                  AND x.status IN ('ASSIGNED','SAT'))
ORDER BY s.seat_id LIMIT 1 \gset

\echo '--- T1 seat already taken in the slot (partial UNIQUE / trigger) ---'
SELECT pg_temp.expect_fail('T1 two students on one seat', '23505', format(
 'UPDATE seatings SET status=%L, cancelled_at=now() WHERE seating_id=%s;
  INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 'CANCELLED', :b_id, :b_st, :a_seat, :b_paper, :a_slot));

\echo '--- T2 same student, two seats in one slot (clash) ---'
SELECT pg_temp.expect_fail('T2 student clash in one slot', '23505', format(
 'INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 :a_st, :free_same, :a_paper, :a_slot));

\echo '--- T3 CBT paper placed in a paper hall (mode rule) ---'
SELECT pg_temp.expect_fail('T3 mode mismatch', '23514', format(
 'UPDATE seatings SET status=%L, cancelled_at=now() WHERE seating_id=%s;
  INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 'CANCELLED', :a_id, :a_st, :free_other, :a_paper, :a_slot));

\echo '--- T4 student not registered for the course ---'
SELECT pg_temp.expect_fail('T4 not registered', '23514', format(
 'INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 :c_st, :free_same, :a_paper, :a_slot));

\echo '--- T5 accessible-seat student on an ordinary seat ---'
SELECT pg_temp.expect_fail('T5 accessible seat needed', '23514', format(
 'UPDATE seatings SET status=%L, cancelled_at=now() WHERE seating_id=%s;
  INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 'CANCELLED', :n_id, :n_st, :n_free, :n_paper, :n_slot));

\echo '--- T6 CANCELLED without cancelled_at (CHECK) ---'
SELECT pg_temp.expect_fail('T6 cancel invariant', '23514', format(
 'UPDATE seatings SET status=%L WHERE seating_id=%s', 'CANCELLED', :a_id));

\echo '--- T7 bad semester format (CHECK) ---'
SELECT pg_temp.expect_fail('T7 semester format', '23514',
 'INSERT INTO exam_slots(semester, slot_date, period) VALUES (''2026-2027'', CURRENT_DATE + 400, ''MORNING'')');

\echo '--- T8 CONTROL: a valid re-seating must SUCCEED ---'
SELECT pg_temp.expect_ok('T8 valid seating accepted', format(
 'UPDATE seatings SET status=%L, cancelled_at=now() WHERE seating_id=%s;
  INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)',
 'CANCELLED', :a_id, :a_st, :free_same, :a_paper, :a_slot));
