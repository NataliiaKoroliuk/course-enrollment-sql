BEGIN;

DROP TABLE IF EXISTS course_prerequisites CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS schedule_sessions CASCADE;
DROP TABLE IF EXISTS course_offerings CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS instructors CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS terms CASCADE;

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE instructors (
    instructor_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL
);

CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_code TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    credits INT NOT NULL CHECK (credits BETWEEN 1 AND 10)
);

CREATE TABLE terms (
    term_id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (start_date < end_date)
);

CREATE TABLE course_offerings (
    offering_id SERIAL PRIMARY KEY,
    course_id INT REFERENCES courses(course_id),
    term_id INT REFERENCES terms(term_id),
    instructor_id INT REFERENCES instructors(instructor_id),
    capacity INT NOT NULL CHECK (capacity > 0)
);

CREATE TABLE schedule_sessions (
    session_id SERIAL PRIMARY KEY,
    offering_id INT REFERENCES course_offerings(offering_id) ON DELETE CASCADE,
    day_of_week INT CHECK (day_of_week BETWEEN 1 AND 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CHECK (start_time < end_time)
);

CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    offering_id INT REFERENCES course_offerings(offering_id) ON DELETE CASCADE,
    student_id INT REFERENCES students(student_id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('enrolled', 'completed', 'dropped')),
    final_grade NUMERIC(5,2),
    UNIQUE (offering_id, student_id)
);

CREATE TABLE course_prerequisites (
    course_id INT REFERENCES courses(course_id) ON DELETE CASCADE,
    prereq_course_id INT REFERENCES courses(course_id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, prereq_course_id),
    CHECK (course_id <> prereq_course_id)
);

COMMIT;
