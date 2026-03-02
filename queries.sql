/* =========================================================
   REQUIRED QUERIES — Course Enrolment System
   Assumptions:
   - terms.name contains '2026 Spring' as latest term
   - enrollments.status in ('enrolled','completed','dropped')
   - completed courses have final_grade NOT NULL (in our data)
   ========================================================= */

-- =========================================================
-- Q1) List courses with the highest enrolment in the last term
-- (time window = latest term by start_date)
-- =========================================================
WITH latest_term AS (
  SELECT term_id
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
)
SELECT
  t.name AS term,
  c.course_code,
  c.title,
  COUNT(e.enrollment_id) AS total_enrollments,
  COUNT(*) FILTER (WHERE e.status = 'enrolled')  AS currently_enrolled,
  COUNT(*) FILTER (WHERE e.status = 'completed') AS completed,
  COUNT(*) FILTER (WHERE e.status = 'dropped')   AS dropped
FROM latest_term lt
JOIN terms t              ON t.term_id = lt.term_id
JOIN course_offerings o   ON o.term_id = lt.term_id
JOIN courses c            ON c.course_id = o.course_id
LEFT JOIN enrollments e   ON e.offering_id = o.offering_id
GROUP BY t.name, c.course_code, c.title
ORDER BY total_enrollments DESC, c.course_code;


-- =========================================================
-- Q2) Find instructors teaching the most credit-hours in the term
-- Credit-hours = SUM(course credits) across offerings in latest term
-- (also show #offerings and #sessions)
-- =========================================================
WITH latest_term AS (
  SELECT term_id
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
),
sessions_per_offering AS (
  SELECT offering_id, COUNT(*) AS sessions_count
  FROM schedule_sessions
  GROUP BY offering_id
)
SELECT
  t.name AS term,
  i.full_name AS instructor,
  COUNT(DISTINCT o.offering_id) AS offerings_taught,
  COALESCE(SUM(c.credits), 0) AS total_credit_hours,
  COALESCE(SUM(spo.sessions_count), 0) AS total_sessions
FROM latest_term lt
JOIN terms t                 ON t.term_id = lt.term_id
JOIN course_offerings o      ON o.term_id = lt.term_id
JOIN instructors i           ON i.instructor_id = o.instructor_id
JOIN courses c               ON c.course_id = o.course_id
LEFT JOIN sessions_per_offering spo ON spo.offering_id = o.offering_id
GROUP BY t.name, i.full_name
ORDER BY total_credit_hours DESC, total_sessions DESC, instructor;


-- =========================================================
-- Q3) Compute pass rates / grade distributions per course (if modeled)
-- Definition: pass = final_grade >= 60, based on COMPLETED enrollments
-- (latest term)
-- =========================================================
WITH latest_term AS (
  SELECT term_id
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
),
completed AS (
  SELECT
    c.course_code,
    c.title,
    e.final_grade
  FROM latest_term lt
  JOIN course_offerings o ON o.term_id = lt.term_id
  JOIN courses c          ON c.course_id = o.course_id
  JOIN enrollments e      ON e.offering_id = o.offering_id
  WHERE e.status = 'completed' AND e.final_grade IS NOT NULL
)
SELECT
  course_code,
  title,
  COUNT(*) AS completed_count,
  ROUND(100.0 * AVG(CASE WHEN final_grade >= 60 THEN 1 ELSE 0 END), 2) AS pass_rate_pct,
  -- simple grade distribution buckets
  COUNT(*) FILTER (WHERE final_grade >= 90) AS a_90_100,
  COUNT(*) FILTER (WHERE final_grade >= 80 AND final_grade < 90) AS b_80_89,
  COUNT(*) FILTER (WHERE final_grade >= 70 AND final_grade < 80) AS c_70_79,
  COUNT(*) FILTER (WHERE final_grade >= 60 AND final_grade < 70) AS d_60_69,
  COUNT(*) FILTER (WHERE final_grade < 60) AS f_below_60,
  ROUND(AVG(final_grade), 2) AS avg_grade
FROM completed
GROUP BY course_code, title
ORDER BY completed_count DESC, course_code;


-- =========================================================
-- Q4) Detect prerequisite violations
-- Students enrolled in a course offering but have NOT completed
-- the prerequisite course with a passing grade (>=60).
--
-- Works for direct prerequisites (course_prerequisites).
-- Window: latest term enrollments with status 'enrolled' or 'completed'
-- =========================================================
WITH latest_term AS (
  SELECT term_id
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
),
current_enrollments AS (
  SELECT
    e.enrollment_id,
    e.student_id,
    e.status,
    o.offering_id,
    o.course_id,
    t.name AS term_name
  FROM latest_term lt
  JOIN course_offerings o ON o.term_id = lt.term_id
  JOIN terms t            ON t.term_id = o.term_id
  JOIN enrollments e      ON e.offering_id = o.offering_id
  WHERE e.status IN ('enrolled', 'completed')
),
required_prereqs AS (
  SELECT
    ce.enrollment_id,
    ce.student_id,
    ce.term_name,
    ce.course_id,
    cp.prereq_course_id
  FROM current_enrollments ce
  JOIN course_prerequisites cp ON cp.course_id = ce.course_id
),
passed_prereqs AS (
  SELECT DISTINCT
    e.student_id,
    o.course_id
  FROM enrollments e
  JOIN course_offerings o ON o.offering_id = e.offering_id
  WHERE e.status = 'completed'
    AND e.final_grade IS NOT NULL
    AND e.final_grade >= 60
)
SELECT
  rp.term_name AS term,
  s.student_id,
  s.first_name,
  s.last_name,
  s.email,
  c.course_code AS enrolled_course,
  c.title       AS enrolled_course_title,
  pc.course_code AS missing_prereq,
  pc.title       AS missing_prereq_title
FROM required_prereqs rp
JOIN students s ON s.student_id = rp.student_id
JOIN courses c  ON c.course_id = rp.course_id
JOIN courses pc ON pc.course_id = rp.prereq_course_id
LEFT JOIN passed_prereqs pp
  ON pp.student_id = rp.student_id
 AND pp.course_id  = rp.prereq_course_id
WHERE pp.student_id IS NULL
ORDER BY term, enrolled_course, student_id, missing_prereq;

-- Q5) Students with schedule conflicts (overlapping sessions) in the latest term
WITH latest_term AS (
  SELECT term_id, name
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
),
enrolled_offerings AS (
  SELECT
    e.student_id,
    o.offering_id
  FROM enrollments e
  JOIN course_offerings o ON o.offering_id = e.offering_id
  JOIN latest_term lt ON lt.term_id = o.term_id
  WHERE e.status = 'enrolled'
),
sessions AS (
  SELECT
    eo.student_id,
    ss.offering_id,
    ss.day_of_week,
    ss.start_time,
    ss.end_time
  FROM enrolled_offerings eo
  JOIN schedule_sessions ss ON ss.offering_id = eo.offering_id
),
conflicts AS (
  SELECT
    s1.student_id,
    s1.day_of_week,
    s1.offering_id AS offering_1,
    s2.offering_id AS offering_2,
    s1.start_time AS start_1,
    s1.end_time   AS end_1,
    s2.start_time AS start_2,
    s2.end_time   AS end_2
  FROM sessions s1
  JOIN sessions s2
    ON s1.student_id = s2.student_id
   AND s1.day_of_week = s2.day_of_week
   AND s1.offering_id < s2.offering_id
   -- overlap condition:
   AND s1.start_time < s2.end_time
   AND s2.start_time < s1.end_time
)
SELECT
  lt.name AS term,
  c.student_id,
  st.first_name,
  st.last_name,
  st.email,
  c.day_of_week,
  c1.course_code AS course_1,
  c2.course_code AS course_2,
  c.start_1, c.end_1,
  c.start_2, c.end_2
FROM conflicts c
JOIN latest_term lt ON TRUE
JOIN students st ON st.student_id = c.student_id
JOIN course_offerings o1 ON o1.offering_id = c.offering_1
JOIN course_offerings o2 ON o2.offering_id = c.offering_2
JOIN courses c1 ON c1.course_id = o1.course_id
JOIN courses c2 ON c2.course_id = o2.course_id
ORDER BY st.student_id, c.day_of_week, c.start_1;


-- Q6) Courses at/over capacity in the latest term (operational)
WITH latest_term AS (
  SELECT term_id, name
  FROM terms
  ORDER BY start_date DESC
  LIMIT 1
),
enrolled_counts AS (
  SELECT
    o.offering_id,
    COUNT(*) FILTER (WHERE e.status = 'enrolled') AS enrolled_now
  FROM course_offerings o
  LEFT JOIN enrollments e ON e.offering_id = o.offering_id
  GROUP BY o.offering_id
)
SELECT
  lt.name AS term,
  c.course_code,
  c.title,
  i.full_name AS instructor,
  o.capacity,
  ec.enrolled_now,
  (o.capacity - ec.enrolled_now) AS seats_left,
  CASE
    WHEN ec.enrolled_now >= o.capacity THEN 'AT/OVER CAPACITY'
    WHEN ec.enrolled_now >= o.capacity - 2 THEN 'NEAR CAPACITY'
    ELSE 'OK'
  END AS capacity_status
FROM latest_term lt
JOIN course_offerings o ON o.term_id = lt.term_id
JOIN courses c ON c.course_id = o.course_id
JOIN instructors i ON i.instructor_id = o.instructor_id
JOIN enrolled_counts ec ON ec.offering_id = o.offering_id
ORDER BY seats_left ASC, c.course_code;

