CREATE DATABASE university_analytics;
use university_analytics;

SELECT COUNT(*) FROM students;

SELECT COUNT(*) FROM courses;

SELECT COUNT(*) FROM enrollments;

SELECT COUNT(*) FROM instructors;

SELECT COUNT(*) FROM classrooms;

SELECT COUNT(*) FROM schedule;


SELECT *
FROM schedule
LIMIT 10;

DESCRIBE students;
DESCRIBE courses;
DESCRIBE enrollments;
DESCRIBE instructors;
DESCRIBE classrooms;
DESCRIBE schedule;

-- CHECK MISSING VALUES IN EACH TABLE --

SELECT *
FROM students
WHERE StudentID IS NULL;

SELECT *
FROM courses
WHERE CourseID IS NULL;

SELECT *
FROM enrollments
WHERE EnrollmentID IS NULL;

SELECT *
FROM instructors
WHERE InstructorID IS NULL;

SELECT *
FROM classrooms
WHERE room_id IS NULL;

SELECT *
FROM schedule
WHERE ScheduleID IS NULL;


-- To find duplicates in ID of each tables for 
SELECT StudentID, COUNT(*)
FROM students
GROUP BY StudentID
HAVING COUNT(*) > 1;

SELECT CourseID, COUNT(*)
FROM courses
GROUP BY CourseID
HAVING COUNT(*) > 1;

SELECT EnrollmentID, COUNT(*)
FROM enrollments
GROUP BY EnrollmentID
HAVING COUNT(*) > 1;

SELECT InstructorID, COUNT(*)
FROM instructors
GROUP BY InstructorID
HAVING COUNT(*) > 1;

SELECT room_id, COUNT(*)
FROM classrooms
GROUP BY room_id
HAVING COUNT(*) > 1;

SELECT ScheduleID, COUNT(*)
FROM schedule
GROUP BY ScheduleID
HAVING COUNT(*) > 1;

-- ADD PRIMARY KEYS 

ALTER TABLE students
ADD PRIMARY KEY (StudentID);

ALTER TABLE courses
ADD PRIMARY KEY (CourseID);
-- error occured because CourseID is text type which will not be used as primary key we should change to varchar

ALTER TABLE courses
MODIFY CourseID VARCHAR(20) NOT NULL;

-- now run the same statement above 
ALTER TABLE courses
ADD PRIMARY KEY (CourseID);

ALTER TABLE enrollments
MODIFY CourseID VARCHAR(20) NOT NULL;

ALTER TABLE schedule
MODIFY CourseID VARCHAR(20) NOT NULL;

ALTER TABLE classrooms
MODIFY room_id VARCHAR(20) NOT NULL;

ALTER TABLE instructors
MODIFY InstructorID VARCHAR(20) NOT NULL;


-- ADD PRIMARY KEYS 
ALTER TABLE instructors
ADD PRIMARY KEY (InstructorID);

ALTER TABLE classrooms
ADD PRIMARY KEY (room_id);

ALTER TABLE schedule
ADD PRIMARY KEY (ScheduleID);


--  EnrollmentID is already INT, so it  can be added primary key directly:
ALTER TABLE enrollments
ADD PRIMARY KEY (EnrollmentID);

SHOW CREATE TABLE courses;
SHOW CREATE TABLE instructors;
SHOW CREATE TABLE classrooms;
SHOW CREATE TABLE schedule;



-- ADD FOREIGN KEYS
ALTER TABLE enrollments
ADD CONSTRAINT fk_enrollment_student
FOREIGN KEY (StudentID)
REFERENCES students(StudentID);


ALTER TABLE enrollments
ADD CONSTRAINT fk_enrollment_course
FOREIGN KEY (CourseID)
REFERENCES courses(CourseID);

ALTER TABLE schedule
ADD CONSTRAINT fk_schedule_course
FOREIGN KEY (CourseID)
REFERENCES courses(CourseID);

ALTER TABLE schedule
MODIFY COLUMN InstructorID VARCHAR(20) NOT NULL;

ALTER TABLE schedule
ADD CONSTRAINT fk_schedule_instructor
FOREIGN KEY (InstructorID)
REFERENCES instructors(InstructorID);

SELECT * from schedule;

DESCRIBE classrooms;

ALTER TABLE schedule
ADD CONSTRAINT fk_schedule_room
FOREIGN KEY (RoomID)
REFERENCES classrooms(room_id); 

SELECT
    s.ScheduleID,
    s.CourseID,
    c.CourseName,
    s.InstructorID,
    i.Instructor,
    s.RoomID,
    r.room_name,
    r.capacity,
    s.Day,
    s.StartTime,
    s.EndTime
FROM schedule s
JOIN courses c
    ON s.CourseID = c.CourseID
JOIN instructors i
    ON s.InstructorID = i.InstructorID
JOIN classrooms r
    ON s.RoomID = r.room_id
LIMIT 20;

-- DATA ANALYSIS --- 


-- CLASSROOM UTILIZATION--
select * from classrooms;
select * from schedule;

SELECT
    r.room_id,
    r.building,
    r.room_name,
    r.capacity,
    COUNT(s.ScheduleID) AS classes_scheduled
FROM classrooms r
LEFT JOIN schedule s
    ON r.room_id = s.RoomID
GROUP BY
    r.room_id,
    r.building,
    r.room_name,
    r.capacity
ORDER BY classes_scheduled DESC;
-- room 9(Engineering) , room 48(Science) , room 40(Arts) have no classes scheduled.

-- KPI FOR MAX CLASS UTIL % AND UNDERUTILIZED %
WITH room_usage AS (
    SELECT
        r.room_id,
        COUNT(s.ScheduleID) AS classes_scheduled
    FROM classrooms r
    LEFT JOIN schedule s
        ON r.room_id = s.RoomID
    GROUP BY r.room_id
)
SELECT
    COUNT(*) AS total_classrooms,

    MAX(classes_scheduled) AS max_classes_scheduled,

    SUM(
        CASE WHEN classes_scheduled =
            (SELECT MAX(classes_scheduled)
             FROM room_usage)
        THEN 1 ELSE 0 END
    ) AS classrooms_at_max,

    ROUND(
        100.0 * SUM(
            CASE WHEN classes_scheduled =
                (SELECT MAX(classes_scheduled)
                 FROM room_usage)
            THEN 1 ELSE 0 END
        ) / COUNT(*), 2
    ) AS pct_classrooms_at_max,

    SUM(
        CASE WHEN classes_scheduled <= 1
        THEN 1 ELSE 0 END
    ) AS underutilized_classrooms,

    ROUND(
        100.0 * SUM(
            CASE WHEN classes_scheduled <= 1
            THEN 1 ELSE 0 END
        ) / COUNT(*), 2
    ) AS pct_underutilized

FROM room_usage;

-- 20% OF THE CLASSROOMS ARE UNDERUTILIZED

-- DEPARTMENT UTILIZATION
-- Which department has more scheduled classes?
SELECT
    c.Department,
    COUNT(s.ScheduleID) AS classes_scheduled
FROM courses c
JOIN schedule s
    ON c.CourseID = s.CourseID
GROUP BY c.Department
ORDER BY classes_scheduled DESC;

-- UNDERUTILIZATION OF CLASSES
SELECT
    s.ScheduleID,
    s.RoomID,
    r.room_name,
    r.capacity,
    COUNT(e.StudentID) AS enrolled_students,
    ROUND(
        COUNT(e.StudentID) * 100.0 / r.capacity,
        2
    ) AS utilization_percent
FROM schedule s
JOIN classrooms r
    ON s.RoomID = r.room_id
LEFT JOIN enrollments e
    ON s.CourseID = e.CourseID
GROUP BY
    s.ScheduleID,
    s.RoomID,
    r.room_name,
    r.capacity
HAVING utilization_percent < 50
ORDER BY utilization_percent ASC;


-- UNDER-UTLIZED CLASSROOMS VS OTHER CLASSROOMS
WITH room_usage AS (
    SELECT
        r.room_id,
        COUNT(s.ScheduleID) AS classes_scheduled
    FROM classrooms r
    LEFT JOIN schedule s
        ON r.room_id = s.RoomID
    GROUP BY r.room_id
)
SELECT
    CASE
        WHEN classes_scheduled <= 1
        THEN 'Underutilized'
        ELSE 'Other Rooms'
    END AS room_category,
    COUNT(*) AS total_classrooms,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM room_usage),
        1
    ) AS percentage
FROM room_usage
GROUP BY room_category;


-- INSTRUCTOR WORKLOAD
SELECT
    i.InstructorID,
    i.Instructor,
    i.Department,
    COUNT(s.ScheduleID) AS classes_taught
FROM instructors i
LEFT JOIN schedule s
    ON i.InstructorID = s.InstructorID
GROUP BY
    i.InstructorID,
    i.Instructor,
    i.Department
ORDER BY classes_taught DESC;


-- INSTRUCTOR DISTRIBUTION PER DEPARTMENT 
SELECT
    i.Department,
    COUNT(DISTINCT i.InstructorID) AS total_instructors,
    COUNT(s.ScheduleID) AS total_classes
FROM instructors i
LEFT JOIN schedule s
    ON i.InstructorID = s.InstructorID
GROUP BY i.Department
ORDER BY total_classes DESC;


-- PEAK SCHEDULING TIMES
-- When are classrooms most heavily scheduled?
SELECT
    Day,
    StartTime,
    COUNT(*) AS classes_scheduled
FROM schedule
GROUP BY
    Day,
    StartTime
ORDER BY classes_scheduled DESC;

-- DAY WITH NUMBER OF CLASSROOMS SCHEDULED
SELECT
    Day,
    COUNT(*) AS total_classes
FROM schedule
GROUP BY Day
ORDER BY total_classes DESC;

-- DAY AND TIME WITH NUMBER OF CLASSROOMS SCHEDULED
SELECT
    Day,
    HOUR(STR_TO_DATE(StartTime, '%H:%i')) AS schedule_hour,
    COUNT(*) AS total_classes
FROM schedule
GROUP BY
    Day,
    HOUR(STR_TO_DATE(StartTime, '%H:%i'))
ORDER BY
    schedule_hour,
    Day;
    
    

-- COURSE SECTION DEMAND
-- WHICH COURSE HAVE HIGHEST STUDENT DEMAND
SELECT
    c.CourseID,
    c.CourseName,
    c.Department,
    COUNT(e.StudentID) AS students_enrolled
FROM courses c
LEFT JOIN enrollments e
    ON c.CourseID = e.CourseID
GROUP BY
    c.CourseID,
    c.CourseName,
    c.Department
ORDER BY students_enrolled DESC; 
-- BIOLOGY CLASSES HAVE HIGH DEMAND FOLLOWED BY COMPUTER SCIENCE

-- COURSE DEMAND DEEP ANALYSIS
WITH course_demand AS (
    SELECT
        c.Department,
        c.CourseID,
        c.CourseName,
        COUNT(e.EnrollmentID) AS total_enrollments
    FROM courses c
    LEFT JOIN enrollments e
        ON c.CourseID = e.CourseID
    GROUP BY
        c.Department,
        c.CourseID,
        c.CourseName
),
ranked_courses AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY Department
            ORDER BY total_enrollments DESC
        ) AS course_rank
    FROM course_demand
    WHERE total_enrollments > 0
)
SELECT
    Department,
    CourseName,
    total_enrollments,
    course_rank
FROM ranked_courses
WHERE course_rank <= 3
ORDER BY Department, course_rank;









