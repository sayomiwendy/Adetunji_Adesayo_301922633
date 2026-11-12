-- P3 - COMMIT vs ROLLBACK: moving a student to a new seat is one atomic unit.
\set ON_ERROR_STOP off
SELECT a.seating_id AS a_id, a.student_id AS st, a.seat_id AS old_seat, a.paper_id AS pp, a.slot_id AS sl,
       h.exam_mode AS mode
FROM seatings a JOIN students s ON s.student_id = a.student_id
JOIN seats t ON t.seat_id = a.seat_id JOIN exam_halls h ON h.hall_id = t.hall_id
WHERE a.status = 'ASSIGNED' AND NOT s.needs_accessible ORDER BY a.seating_id LIMIT 1 \gset
SELECT t.seat_id AS good_seat FROM seats t JOIN exam_halls h ON h.hall_id = t.hall_id
WHERE h.exam_mode = :'mode' AND NOT t.is_accessible
  AND NOT EXISTS (SELECT 1 FROM seatings x WHERE x.seat_id = t.seat_id AND x.slot_id = :sl AND x.status IN ('ASSIGNED','SAT'))
ORDER BY t.seat_id LIMIT 1 \gset
SELECT t.seat_id AS bad_seat FROM seats t JOIN exam_halls h ON h.hall_id = t.hall_id
WHERE h.exam_mode <> :'mode' AND NOT t.is_accessible
  AND NOT EXISTS (SELECT 1 FROM seatings x WHERE x.seat_id = t.seat_id AND x.slot_id = :sl AND x.status IN ('ASSIGNED','SAT'))
ORDER BY t.seat_id LIMIT 1 \gset

\echo '=== BEFORE: the student holds seat' :old_seat
SELECT seating_id, seat_id, status FROM seatings WHERE student_id = :st AND slot_id = :sl AND status IN ('ASSIGNED','SAT');

\echo '=== Test A: move to a seat in the WRONG kind of hall -> error -> ROLLBACK ==='
BEGIN;
UPDATE seatings SET status = 'CANCELLED', cancelled_at = now() WHERE seating_id = :a_id;
INSERT INTO seatings (student_id, seat_id, paper_id, slot_id) VALUES (:st, :bad_seat, :pp, :sl);
ROLLBACK;
\echo '=== AFTER rollback: old seating is still there (nothing half-done) ==='
SELECT seating_id, seat_id, status FROM seatings WHERE student_id = :st AND slot_id = :sl AND status IN ('ASSIGNED','SAT');

\echo '=== Test B: move to a valid free seat -> COMMIT ==='
BEGIN;
UPDATE seatings SET status = 'CANCELLED', cancelled_at = now() WHERE seating_id = :a_id;
INSERT INTO seatings (student_id, seat_id, paper_id, slot_id) VALUES (:st, :good_seat, :pp, :sl);
COMMIT;
\echo '=== AFTER commit: new seat is active, old row is CANCELLED ==='
SELECT seating_id, seat_id, status FROM seatings WHERE student_id = :st AND slot_id = :sl ORDER BY seating_id;

\echo '=== clean-up: put the student back on the original seat ==='
BEGIN;
UPDATE seatings SET status = 'CANCELLED', cancelled_at = now() WHERE student_id = :st AND slot_id = :sl AND status = 'ASSIGNED';
INSERT INTO seatings (student_id, seat_id, paper_id, slot_id) VALUES (:st, :old_seat, :pp, :sl);
COMMIT;
SELECT seating_id, seat_id, status FROM seatings WHERE student_id = :st AND slot_id = :sl AND status = 'ASSIGNED';
