-- Portfolio 1 - Bulk generator: one seating per registration (about 64,800 rows).
-- Past semesters -> SAT (or ABSENT for about 3%), current semester -> ASSIGNED.
-- Students are ranked inside (slot, mode); the k-th student gets the k-th seat of that mode,
-- students who need an accessible seat are ranked first and accessible seats are first.
-- Triggers are switched off for speed and the same rules are then audited with SQL (must be 0).
ALTER TABLE seatings DISABLE TRIGGER USER;

INSERT INTO seatings (student_id, seat_id, paper_id, slot_id, status, assigned_at, cancelled_at)
WITH reg AS (
    SELECT r.student_id, st.needs_accessible, p.paper_id, p.slot_id, c.exam_mode, sl.slot_date,
           ROW_NUMBER() OVER (PARTITION BY p.slot_id, c.exam_mode
                              ORDER BY st.needs_accessible DESC, r.student_id) AS rk
    FROM registrations r
    JOIN students    st ON st.student_id = r.student_id
    JOIN courses     c  ON c.course_code = r.course_code
    JOIN exam_slots  sl ON sl.semester = r.semester
    JOIN exam_papers p  ON p.course_code = r.course_code AND p.slot_id = sl.slot_id
), sk AS (
    SELECT s.seat_id, h.exam_mode,
           ROW_NUMBER() OVER (PARTITION BY h.exam_mode ORDER BY s.is_accessible DESC, s.seat_id) AS rk
    FROM seats s JOIN exam_halls h ON h.hall_id = s.hall_id
)
SELECT reg.student_id, sk.seat_id, reg.paper_id, reg.slot_id,
       CASE WHEN reg.slot_date >= CURRENT_DATE THEN 'ASSIGNED'
            WHEN (reg.student_id + reg.slot_id) % 33 = 0 THEN 'ABSENT'
            ELSE 'SAT' END,
       ((reg.slot_date - 14)::timestamp + ((reg.student_id * 7) % 600) * interval '1 minute')
           AT TIME ZONE 'Africa/Lagos',
       NULL
FROM reg JOIN sk ON sk.exam_mode = reg.exam_mode AND sk.rk = reg.rk;

ALTER TABLE seatings ENABLE TRIGGER USER;

SELECT 'TOTAL SEATINGS' AS metric, COUNT(*)::text AS value FROM seatings
UNION ALL SELECT 'registrations (must equal seatings)', COUNT(*)::text FROM registrations
UNION ALL SELECT status, COUNT(*)::text FROM seatings GROUP BY status
UNION ALL SELECT 'future slots with ASSIGNED seats',
       COUNT(DISTINCT s.slot_id)::text FROM seatings s WHERE s.status = 'ASSIGNED';

-- audits: every line must be 0
SELECT 'mode mismatch' AS audit, COUNT(*) AS violations
FROM seatings a JOIN seats s ON s.seat_id = a.seat_id JOIN exam_halls h ON h.hall_id = s.hall_id
JOIN exam_papers p ON p.paper_id = a.paper_id JOIN courses c ON c.course_code = p.course_code
WHERE h.exam_mode <> c.exam_mode
UNION ALL
SELECT 'not registered', COUNT(*)
FROM seatings a JOIN exam_papers p ON p.paper_id = a.paper_id JOIN exam_slots sl ON sl.slot_id = a.slot_id
WHERE NOT EXISTS (SELECT 1 FROM registrations r WHERE r.student_id = a.student_id
                  AND r.course_code = p.course_code AND r.semester = sl.semester)
UNION ALL
SELECT 'needs accessible but not accessible seat', COUNT(*)
FROM seatings a JOIN students st ON st.student_id = a.student_id JOIN seats s ON s.seat_id = a.seat_id
WHERE st.needs_accessible AND NOT s.is_accessible;
