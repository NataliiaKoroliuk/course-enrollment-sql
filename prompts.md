# LLM Usage

## Tool
ChatGPT (OpenAI)

## Purpose of Use
ChatGPT was used as a supporting tool during the development of the project.  
The tool assisted with several technical tasks but did not make final design decisions.

Specifically, ChatGPT was used for:

- generating example scripts for **sample data population**;
- reviewing and **validating SQL queries**;
- identifying and correcting **syntax and semantic errors**;
- providing recommendations for **SQL query optimization**;
- suggesting improvements for **database structure and constraints**.

All outputs produced by ChatGPT were reviewed, validated, and adapted by the project team before being included in the final implementation.

## Tasks NOT delegated to the LLM

The following tasks were completed entirely by the team:

- final **database schema design**;
- selection of entities and relationships in the ER model;
- implementation and testing of SQL scripts;
- interpretation of query results;
- preparation of the final report.

## Evidence

Below are examples of prompts used during development.

---

### Prompt Example 1

**Prompt**

Generate SQL insert examples to populate a course enrolment database with students, instructors, and enrollments.

**Use**

The output helped generate initial data population logic and automate the creation of multiple student records using SQL functions such as `generate_series()`.

---

### Prompt Example 2

**Prompt**

Review this SQL query and check for logical or semantic errors.

**Use**

ChatGPT helped identify potential issues in joins and filtering conditions and suggested corrections.

---

### Prompt Example 3

**Prompt**

How can this SQL query be optimized for readability and performance?

**Use**

ChatGPT provided suggestions such as using **CTEs**, restructuring joins, and improving query readability.
