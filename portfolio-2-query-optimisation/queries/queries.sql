-- P2 query set, run BEFORE and AFTER the indexes (same file, so the comparison is fair).
-- Q1-Q4 are selective (a few hundred rows out of 64,800) so indexes can help.
-- Q5-Q6 read the whole table on purpose, to show where indexes do NOT help.
\set ON_ERROR_STOP on
\echo '--- Q1: one student''s seating history ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT sl.slot_date, sl.period, p.course_code, a.status
FROM seatings a
JOIN exam_slots sl ON sl.slot_id = a.slot_id
JOIN exam_papers p ON p.paper_id = a.paper_id
WHERE a.student_id = 777
ORDER BY a.assigned_at DESC;

\echo '--- Q2: seat usage by status for ONE exam slot ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.status, COUNT(*) AS seats_used
FROM seatings a
WHERE a.slot_id = (SELECT MAX(slot_id) - 3 FROM exam_slots WHERE slot_date < CURRENT_DATE)
GROUP BY a.status ORDER BY a.status;

\echo '--- Q3: absentees for one course across all semesters ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT st.matric_number, st.full_name, sl.semester
FROM exam_papers p
JOIN seatings a    ON a.paper_id = p.paper_id
JOIN students st   ON st.student_id = a.student_id
JOIN exam_slots sl ON sl.slot_id = a.slot_id
WHERE p.course_code = 'CSC 201' AND a.status = 'ABSENT'
ORDER BY sl.semester, st.matric_number;

\echo '--- Q4: roster of one hall for one slot ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.seat_code, st.matric_number, st.full_name, p.course_code
FROM seatings a
JOIN seats s       ON s.seat_id = a.seat_id
JOIN students st   ON st.student_id = a.student_id
JOIN exam_papers p ON p.paper_id = a.paper_id
WHERE s.hall_id = (SELECT hall_id FROM exam_halls WHERE hall_name = 'Main Auditorium')
  AND a.slot_id = (SELECT MAX(slot_id) - 3 FROM exam_slots WHERE slot_date < CURRENT_DATE)
ORDER BY s.seat_code;

\echo '--- Q5 (full scan on purpose): seatings per hall per status ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.hall_name, a.status, COUNT(*) AS n
FROM seatings a JOIN seats s ON s.seat_id = a.seat_id JOIN exam_halls h ON h.hall_id = s.hall_id
GROUP BY h.hall_name, a.status ORDER BY h.hall_name, a.status;

\echo '--- Q6 (full scan on purpose): attendance rate per department ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT st.department,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.status = 'SAT') / NULLIF(COUNT(*) FILTER (WHERE a.status IN ('SAT','ABSENT')), 0), 2) AS attendance_pct
FROM seatings a JOIN students st ON st.student_id = a.student_id
GROUP BY st.department ORDER BY st.department;
