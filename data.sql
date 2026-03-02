BEGIN;

-- Clean data (safe order because of FKs)
TRUNCATE TABLE
  enrollments,
  schedule_sessions,
  course_offerings,
  course_prerequisites,
  students,
  instructors,
  courses,
  terms
RESTART IDENTITY CASCADE;

-- 1) Terms (2 terms so "latest term" logic works)
INSERT INTO terms (name, start_date, end_date) VALUES
('2025 Fall',   '2025-09-01', '2025-12-20'),
('2026 Spring', '2026-02-01', '2026-05-25');

-- 2) Instructors (>= 6)
INSERT INTO instructors (full_name, email) VALUES
('Dr. Alice Brown',  'alice.brown@uni.edu'),
('Dr. Bob Smith',    'bob.smith@uni.edu'),
('Dr. Carol Lee',    'carol.lee@uni.edu'),
('Dr. David Kim',    'david.kim@uni.edu'),
('Dr. Emma Davis',   'emma.davis@uni.edu'),
('Dr. Frank Miller', 'frank.miller@uni.edu');

-- 3) Courses (>= 8)
INSERT INTO courses (course_code, title, credits) VALUES
('CS101',   'Intro to Programming', 3),
('CS102',   'Data Structures', 4),
('CS201',   'Databases', 3),
('CS202',   'Computer Networks', 3),
('MATH101', 'Calculus I', 4),
('STAT201', 'Statistics', 3),
('BUS101',  'Business Fundamentals', 3),
('ENG101',  'Academic Writing', 2),
('DS301',   'Product Analytics', 3),
('AI210',   'AI in Business', 3);

-- 4) Prerequisites (modelled)
-- CS102 requires CS101
-- CS201 requires CS102
-- DS301 requires STAT201
-- AI210 requires BUS101
INSERT INTO course_prerequisites (course_id, prereq_course_id)
SELECT c.course_id, p.course_id
FROM courses c
JOIN courses p ON (
  (c.course_code = 'CS102'  AND p.course_code = 'CS101') OR
  (c.course_code = 'CS201'  AND p.course_code = 'CS102') OR
  (c.course_code = 'DS301'  AND p.course_code = 'STAT201') OR
  (c.course_code = 'AI210'  AND p.course_code = 'BUS101')
);

-- 5) Students (>= 40)
INSERT INTO students (first_name, last_name, email)
SELECT
  'Student' || gs::text,
  'Test',
  'student' || gs::text || '@example.com'
FROM generate_series(1, 40) AS gs;

-- 6) Course offerings (10 offerings across 2 terms)
-- 3 offerings in 2025 Fall and 7 offerings in 2026 Spring (latest term)

-- 6a) Fall offerings (3)
WITH term_ids AS (
  SELECT (SELECT term_id FROM terms WHERE name='2025 Fall') AS fall_id
),
course_ids AS (
  SELECT course_code, course_id
  FROM courses
  WHERE course_code IN ('CS101','MATH101','ENG101')
),
one_instructor AS (
  SELECT instructor_id FROM instructors ORDER BY instructor_id LIMIT 1
)
INSERT INTO course_offerings (course_id, term_id, instructor_id, capacity)
SELECT
  c.course_id,
  t.fall_id,
  i.instructor_id,
  CASE
    WHEN c.course_code='CS101' THEN 20
    WHEN c.course_code='MATH101' THEN 15
    ELSE 25
  END AS capacity
FROM term_ids t
JOIN course_ids c ON TRUE
JOIN one_instructor i ON TRUE;

-- 6b) Spring offerings (7) - FIXED instructor assignment (no bytea subscripting)
WITH term_ids AS (
  SELECT (SELECT term_id FROM terms WHERE name='2026 Spring') AS spring_id
),
course_ids AS (
  SELECT course_code, course_id
  FROM courses
  WHERE course_code IN ('CS101','CS102','CS201','STAT201','BUS101','DS301','AI210')
),
ranked_courses AS (
  SELECT
    course_id,
    course_code,
    ROW_NUMBER() OVER (ORDER BY course_code) AS rn
  FROM course_ids
)
INSERT INTO course_offerings (course_id, term_id, instructor_id, capacity)
SELECT
  rc.course_id,
  t.spring_id,
  ((rc.rn - 1) % 6 + 1) AS instructor_id,  -- cycles 1..6
  CASE
    WHEN rc.course_code IN ('CS102','CS201') THEN 18
    WHEN rc.course_code IN ('STAT201','DS301') THEN 16
    ELSE 22
  END AS capacity
FROM term_ids t
JOIN ranked_courses rc ON TRUE;

-- 7) Schedule sessions (>= 10).
-- We'll add 2 sessions per offering (so 20 sessions total for 10 offerings)

INSERT INTO schedule_sessions (offering_id, day_of_week, start_time, end_time, location)
SELECT
  o.offering_id,
  CASE WHEN (o.offering_id % 2)=0 THEN 2 ELSE 4 END AS day_of_week,          -- Tue/Thu
  CASE WHEN (o.offering_id % 3)=0 THEN TIME '10:00' ELSE TIME '14:00' END,   -- 10:00 or 14:00
  CASE WHEN (o.offering_id % 3)=0 THEN TIME '11:30' ELSE TIME '15:30' END,
  'Room ' || (100 + o.offering_id)::text
FROM course_offerings o;

INSERT INTO schedule_sessions (offering_id, day_of_week, start_time, end_time, location)
SELECT
  o.offering_id,
  CASE WHEN (o.offering_id % 2)=0 THEN 3 ELSE 5 END AS day_of_week,          -- Wed/Fri
  CASE WHEN (o.offering_id % 3)=0 THEN TIME '10:00' ELSE TIME '14:00' END,
  CASE WHEN (o.offering_id % 3)=0 THEN TIME '11:30' ELSE TIME '15:30' END,
  'Room ' || (200 + o.offering_id)::text
FROM course_offerings o;

-- 8) Enrollments (>= 60)
-- Strategy:
-- - Create completed records in 2025 Fall for CS101 + MATH101 (students 1..20)
-- - Create many Spring enrollments, plus some completed Spring with grades (for pass rate)
-- - Create intentional prerequisite violations in Spring (so violations query returns rows)

WITH off AS (
  SELECT o.offering_id, t.name AS term, c.course_code
  FROM course_offerings o
  JOIN terms t ON t.term_id = o.term_id
  JOIN courses c ON c.course_id = o.course_id
)
-- 8a) Fall completed (students 1..20 complete CS101 + MATH101 with grades)
INSERT INTO enrollments (offering_id, student_id, status, final_grade)
SELECT
  o.offering_id,
  s.student_id,
  'completed' AS status,
  (70 + (s.student_id % 25))::numeric(5,2) AS final_grade
FROM off o
JOIN students s ON s.student_id BETWEEN 1 AND 20
WHERE o.term='2025 Fall' AND o.course_code IN ('CS101','MATH101');

-- 8b) Spring enrolled: students 1..30 enroll into CS101, CS102, STAT201, BUS101
WITH off AS (
  SELECT o.offering_id, t.name AS term, c.course_code
  FROM course_offerings o
  JOIN terms t ON t.term_id = o.term_id
  JOIN courses c ON c.course_id = o.course_id
)
INSERT INTO enrollments (offering_id, student_id, status, final_grade)
SELECT
  o.offering_id,
  s.student_id,
  'enrolled' AS status,
  NULL::numeric
FROM off o
JOIN students s ON s.student_id BETWEEN 1 AND 30
WHERE o.term='2026 Spring' AND o.course_code IN ('CS101','CS102','STAT201','BUS101')
ON CONFLICT DO NOTHING;

-- 8c) Spring completed: students 1..15 complete STAT201 and BUS101 with grades
WITH off AS (
  SELECT o.offering_id, t.name AS term, c.course_code
  FROM course_offerings o
  JOIN terms t ON t.term_id = o.term_id
  JOIN courses c ON c.course_id = o.course_id
)
INSERT INTO enrollments (offering_id, student_id, status, final_grade)
SELECT
  o.offering_id,
  s.student_id,
  'completed' AS status,
  (55 + (s.student_id % 45))::numeric(5,2) AS final_grade
FROM off o
JOIN students s ON s.student_id BETWEEN 1 AND 15
WHERE o.term='2026 Spring' AND o.course_code IN ('STAT201','BUS101')
ON CONFLICT (offering_id, student_id) DO UPDATE
SET status='completed', final_grade=EXCLUDED.final_grade;

-- 8d) Spring: DS301 and AI210 enrollments (some will violate prereqs)
WITH off AS (
  SELECT o.offering_id, t.name AS term, c.course_code
  FROM course_offerings o
  JOIN terms t ON t.term_id = o.term_id
  JOIN courses c ON c.course_id = o.course_id
)
INSERT INTO enrollments (offering_id, student_id, status, final_grade)
SELECT
  o.offering_id,
  s.student_id,
  'enrolled' AS status,
  NULL::numeric
FROM off o
JOIN students s ON s.student_id BETWEEN 10 AND 35
WHERE o.term='2026 Spring' AND o.course_code IN ('DS301','AI210')
ON CONFLICT DO NOTHING;

-- 8e) Spring: CS201 enrollments (requires CS102 which requires CS101)
WITH off AS (
  SELECT o.offering_id, t.name AS term, c.course_code
  FROM course_offerings o
  JOIN terms t ON t.term_id = o.term_id
  JOIN courses c ON c.course_id = o.course_id
)
INSERT INTO enrollments (offering_id, student_id, status, final_grade)
SELECT
  o.offering_id,
  s.student_id,
  'enrolled' AS status,
  NULL::numeric
FROM off o
JOIN students s ON s.student_id BETWEEN 5 AND 28
WHERE o.term='2026 Spring' AND o.course_code = 'CS201'
ON CONFLICT DO NOTHING;

COMMIT;
