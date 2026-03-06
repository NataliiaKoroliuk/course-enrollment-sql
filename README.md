# Course Enrolment System
**Relational Modeling and SQL Analytics Project**
**1. Introduction**

This project presents the design and implementation of a relational database for a Course Enrolment System. The system models the process of students enrolling in courses offered during academic terms, while maintaining information about instructors, course schedules, prerequisites, and enrollment outcomes.

The objective of the project is to demonstrate the full workflow of relational database development:

- conceptual modeling using an Entity–Relationship (ER) diagram,
- transformation into a normalized relational schema,
- implementation of the schema using PostgreSQL,
- generation of sample data, and
- development of SQL queries that provide operational and analytical insights.

The database design ensures referential integrity through the use of primary keys, foreign keys, and constraints, and supports realistic queries related to course enrollment, instructor workload, prerequisite validation, and schedule conflicts.

**2. Conceptual Design (ER Model)**

The conceptual design is represented using an Entity–Relationship (ER) diagram. The model captures the key entities involved in a university course enrollment system and the relationships between them.

Main entities in the system

The following core entities were identified:

- Students – individuals enrolled in the university who may register for course offerings.
- Instructors – faculty members responsible for teaching course offerings.
- Courses – academic subjects defined by a course code, title, and number of credits.
- Terms – academic periods (e.g., Fall 2025, Spring 2026).
- Course Offerings – instances of courses offered during a specific term and taught by a specific instructor.
- Schedule Sessions – individual weekly meeting sessions for each course offering.
- Enrollments – records representing a student registering for a course offering.
- Course Prerequisites – relationships indicating that a course requires completion of another course before enrollment.

Relationships

The following relationships are modeled:

- A student can have multiple enrollments.
- A course offering can have multiple enrollments.
- A course can have multiple course offerings across different terms.
- A course offering is taught by exactly one instructor.
- A course offering can have multiple schedule sessions.
- A course can have zero or multiple prerequisites.

This structure allows the system to represent real-world academic scheduling and enrollment constraints.

**3. Relational Schema**

The ER model was translated into the following relational schema:

- students
- instructors
- courses
- terms
- course_offerings
- schedule_sessions
- enrollments
- course_prerequisites

Each table includes clearly defined Primary Keys (PK) and Foreign Keys (FK).

Example key relationships

- course_offerings.course_id → courses.course_id
- course_offerings.term_id → terms.term_id
- course_offerings.instructor_id → instructors.instructor_id
- schedule_sessions.offering_id → course_offerings.offering_id
- enrollments.student_id → students.student_id
- enrollments.offering_id → course_offerings.offering_id
- course_prerequisites.course_id → courses.course_id

Constraints such as UNIQUE, CHECK, and NOT NULL are used to enforce business rules.
For example:

- course credits must be between 1 and 10;
- schedule sessions must have start_time < end_time;
- course capacity must be greater than zero.

**4. Normalization**

The database schema was designed to satisfy Third Normal Form (3NF).

The normalization process ensured that:

1. Each table has a primary key.
2. All attributes depend on the whole key.
3. No transitive dependencies exist.

Examples of normalization decisions:

- Course offerings were separated from courses so that the same course can be offered multiple times across different terms.
- Schedule sessions were modeled as a separate table to allow each offering to have multiple weekly sessions.
- Enrollments were modeled as a junction table between students and course offerings.
- Course prerequisites were implemented using a self-referencing table to represent many-to-many relationships between courses.

This design eliminates redundancy and maintains data consistency.

**5. Data Generation**

Sample data was generated to simulate a realistic academic environment.

The dataset includes:

- 40 students;
- 6 instructors; 
- 10 courses;
- 2 academic terms;
- 10 course offerings;
- 20 schedule sessions;
- 60+ enrollments.

Data generation was implemented using SQL techniques such as:

- generate_series() for creating multiple student records,
- structured inserts for courses and instructors,
- automated enrollment generation.

The generated dataset ensures that analytical queries return meaningful and non-empty results.
