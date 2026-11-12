-- Portfolio 1 - Seed: halls, seats, courses, students, slots, papers, registrations.
-- 5 halls (2 CBT labs, 3 paper halls), 36 courses, 1,200 students, 9 semesters.

INSERT INTO exam_halls (hall_name, building, exam_mode) VALUES
    ('CBT Lab Alpha',   'ICT Centre',          'CBT'),
    ('CBT Lab Beta',    'ICT Centre',          'CBT'),
    ('Main Auditorium', 'Admin Block',         'PAPER'),
    ('Hall B',          'Faculty of Science',  'PAPER'),
    ('Hall C',          'Faculty of Arts',     'PAPER');

-- seats: Alpha 130, Beta 130, Auditorium 300, B 150, C 150; first 10 seats of each hall are accessible
INSERT INTO seats (hall_id, seat_code, is_accessible)
SELECT h.hall_id, 'S' || LPAD(g::text, 3, '0'), g <= 10
FROM exam_halls h
JOIN LATERAL generate_series(1, CASE h.hall_name WHEN 'Main Auditorium' THEN 300
                                                   WHEN 'Hall B' THEN 150 WHEN 'Hall C' THEN 150
                                                   ELSE 130 END) g ON true;

-- 36 courses: the first 12 are CBT papers, the other 24 are written (PAPER) papers
INSERT INTO courses (course_code, title, department, exam_mode, timetable_no)
SELECT code, title, dept, CASE WHEN n <= 12 THEN 'CBT' ELSE 'PAPER' END, n
FROM (VALUES
 (1,'CSC 101','Introduction to Computer Science','Computer Science'),
 (2,'ACC 101','Principles of Accounting','Accounting'),
 (3,'ECO 101','Introductory Economics','Economics'),
 (4,'BUS 101','Introduction to Business','Business Administration'),
 (5,'MAC 101','Introduction to Mass Communication','Mass Communication'),
 (6,'CYB 101','Introduction to Cybersecurity','Cybersecurity'),
 (7,'CSC 102','Programming in Python','Computer Science'),
 (8,'ACC 102','Financial Accounting I','Accounting'),
 (9,'ECO 102','Microeconomics','Economics'),
 (10,'BUS 102','Business Mathematics','Business Administration'),
 (11,'MAC 102','Media Writing','Mass Communication'),
 (12,'CYB 102','Computer Networks Basics','Cybersecurity'),
 (13,'CSC 201','Data Structures','Computer Science'),
 (14,'ACC 201','Cost Accounting','Accounting'),
 (15,'ECO 201','Macroeconomics','Economics'),
 (16,'BUS 201','Organisational Behaviour','Business Administration'),
 (17,'MAC 201','Broadcast Journalism','Mass Communication'),
 (18,'CYB 201','Network Security','Cybersecurity'),
 (19,'CSC 202','Database Systems','Computer Science'),
 (20,'ACC 202','Taxation','Accounting'),
 (21,'ECO 202','Development Economics','Economics'),
 (22,'BUS 202','Marketing Management','Business Administration'),
 (23,'MAC 202','Public Relations','Mass Communication'),
 (24,'CYB 202','Ethical Hacking','Cybersecurity'),
 (25,'CSC 301','Operating Systems','Computer Science'),
 (26,'ACC 301','Auditing','Accounting'),
 (27,'ECO 301','Econometrics','Economics'),
 (28,'BUS 301','Strategic Management','Business Administration'),
 (29,'MAC 301','Media Law and Ethics','Mass Communication'),
 (30,'CYB 301','Digital Forensics','Cybersecurity'),
 (31,'CSC 302','Software Engineering','Computer Science'),
 (32,'ACC 302','Corporate Finance','Accounting'),
 (33,'ECO 302','Public Finance','Economics'),
 (34,'BUS 302','Entrepreneurship','Business Administration'),
 (35,'MAC 302','Digital Media Production','Mass Communication'),
 (36,'CYB 302','Cloud Security','Cybersecurity')
) AS v(n, code, title, dept);

-- 1,200 students with Nigerian names; every 50th student needs an accessible seat
WITH f AS (SELECT ARRAY['Chinedu','Aisha','Tunde','Ngozi','Emeka','Fatima','Segun','Blessing','Ibrahim','Chiamaka',
  'Olumide','Zainab','Kelechi','Yewande','Uche','Hauwa','Babatunde','Amaka','Musa','Folake',
  'Obinna','Halima','Damilola','Ifeoma','Sani','Temitope','Nnamdi','Bukola','Abubakar','Chioma',
  'Kayode','Rukayat','Ikenna','Adaeze','Gbenga','Mariam','Tochukwu','Oluwaseun','Yusuf','Nneka'] AS a),
l AS (SELECT ARRAY['Okafor','Bello','Adeyemi','Eze','Danjuma','Okonkwo','Balogun','Nwosu','Abdullahi','Ogunleye',
  'Ibe','Salisu','Afolabi','Chukwu','Lawal','Obi','Adebayo','Garba','Onyeama','Fashola',
  'Umeh','Yakubu','Ajayi','Nwachukwu','Suleiman','Olawale','Anyanwu','Mohammed','Ogundipe','Ezekwesili',
  'Akpan','Ibrahim','Oladipo','Nnaji','Hassan','Adewale','Okoro','Usman','Ojo','Egbuna'] AS a)
INSERT INTO students (matric_number, full_name, email, department, level, needs_accessible)
SELECT 'EX/' || LPAD(g::text, 5, '0'),
       f.a[1 + (g*3) % 40] || ' ' || l.a[1 + (g/3 + g*11) % 40],
       lower(f.a[1 + (g*3) % 40] || '.' || l.a[1 + (g/3 + g*11) % 40]) || g || '@student.miva.edu.ng',
       (ARRAY['Computer Science','Accounting','Economics','Business Administration','Mass Communication','Cybersecurity'])[1 + g % 6],
       100 * (1 + (g/6) % 4),
       g % 50 = 0
FROM generate_series(1, 1200) g, f, l;

-- 9 semesters: 8 past ones (182 days apart) and the current one starting tomorrow.
-- Each semester has 12 slots = 6 days x (MORNING, AFTERNOON).
INSERT INTO exam_slots (semester, slot_date, period)
SELECT semester, slot_date, period FROM (
SELECT s.semester, s.start_date + d AS slot_date, p AS period
FROM (VALUES
  (0,'2022/2023-S1'),(1,'2022/2023-S2'),(2,'2023/2024-S1'),(3,'2023/2024-S2'),
  (4,'2024/2025-S1'),(5,'2024/2025-S2'),(6,'2025/2026-S1'),(7,'2025/2026-S2')
) AS h(q, semester)
CROSS JOIN LATERAL (SELECT h.semester, (CURRENT_DATE - (8 - h.q) * 182) AS start_date) s
CROSS JOIN generate_series(0, 5) d
CROSS JOIN (VALUES ('MORNING'),('AFTERNOON')) AS pp(p)
UNION ALL
SELECT '2026/2027-S1', CURRENT_DATE + 1 + d, p
FROM generate_series(0, 5) d CROSS JOIN (VALUES ('MORNING'),('AFTERNOON')) AS pp(p)
) x ORDER BY slot_date, period DESC;   -- ordered so slot_id grows with the date (semesters are contiguous ranges)

-- papers: slot number k (0..11, date order inside the semester) examines courses with index = k (mod 12)
INSERT INTO exam_papers (course_code, slot_id)
SELECT c.course_code, sl.slot_id
FROM (SELECT slot_id,
             ROW_NUMBER() OVER (PARTITION BY semester ORDER BY slot_date, period DESC) - 1 AS k
      FROM exam_slots) sl
JOIN courses c ON (c.timetable_no - 1) % 12 = sl.k;

-- registrations: each student takes 6 courses per semester, one in each of 6 different slots
-- (slot index = (s + 2j) mod 12 for j = 0..5, so a student never has two papers in the same slot)
INSERT INTO registrations (student_id, course_code, semester)
SELECT st.student_id, c.course_code, sem.semester
FROM (SELECT student_id, ROW_NUMBER() OVER (ORDER BY student_id) - 1 AS s FROM students) st
CROSS JOIN (SELECT DISTINCT semester FROM exam_slots) sem
CROSS JOIN generate_series(0, 5) j
JOIN courses c ON c.timetable_no - 1 = ((st.s % 12 + 2 * j) % 12) + 12 * ((st.s / 12 + j) % 3);

SELECT 'exam_halls' AS table_name, COUNT(*) FROM exam_halls
UNION ALL SELECT 'seats', COUNT(*) FROM seats
UNION ALL SELECT 'courses', COUNT(*) FROM courses
UNION ALL SELECT 'students', COUNT(*) FROM students
UNION ALL SELECT 'exam_slots', COUNT(*) FROM exam_slots
UNION ALL SELECT 'exam_papers', COUNT(*) FROM exam_papers
UNION ALL SELECT 'registrations', COUNT(*) FROM registrations ORDER BY 1;
