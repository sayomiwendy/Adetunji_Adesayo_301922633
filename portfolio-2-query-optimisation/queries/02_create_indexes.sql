-- P2 optimisation indexes (the P1 partial UNIQUE indexes already exist; these add what the queries need)
CREATE INDEX idx_seat_student_time ON seatings (student_id, assigned_at DESC);
CREATE INDEX idx_seat_slot         ON seatings (slot_id, status);
CREATE INDEX idx_seat_paper        ON seatings (paper_id, status);
ANALYZE seatings;
SELECT indexname FROM pg_indexes WHERE tablename = 'seatings' ORDER BY 1;
