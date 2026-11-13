-- =====================================================
-- 02_load_data.sql  (Phase 2, Team T0137)
-- Loads the 11 CSV files into the tables from 01_schema.sql.
--
-- How to run:
--   1. Unzip seed_data.zip in the project root (the folder that has seed_data/)
--   2. Run this file from that same folder:
--        psql -d <database> -f sql/02_load_data.sql
--
-- Order matters. A table with a foreign key can only be loaded after
-- the table it points to, so we load parents first and children after.
--
-- For the large dataset (Phase 5) we change only the folder name:
-- seed_data  ->  large_data
-- =====================================================

SET search_path TO duolingo;


-- Step 1: tables that do not point to any other table
\copy languages FROM 'seed_data/languages.csv' WITH (FORMAT csv, HEADER true)
\copy achievements FROM 'seed_data/achievements.csv' WITH (FORMAT csv, HEADER true)

-- Step 2: courses point to languages
\copy courses FROM 'seed_data/courses.csv' WITH (FORMAT csv, HEADER true)

-- Step 3: course content, in this order: courses -> units -> lessons
\copy units FROM 'seed_data/units.csv' WITH (FORMAT csv, HEADER true)
\copy lessons FROM 'seed_data/lessons.csv' WITH (FORMAT csv, HEADER true)

-- Step 4: learners (referred_by points to the same table; the load still works
-- because PostgreSQL checks the foreign keys after the rows are inserted)
\copy learners FROM 'seed_data/learners.csv' WITH (FORMAT csv, HEADER true)

-- Step 5: tables that point to learners (and to courses, lessons or achievements)
\copy enrollments FROM 'seed_data/enrollments.csv' WITH (FORMAT csv, HEADER true)
\copy lesson_attempts FROM 'seed_data/lesson_attempts.csv' WITH (FORMAT csv, HEADER true)
\copy daily_activity FROM 'seed_data/daily_activity.csv' WITH (FORMAT csv, HEADER true)
\copy league_memberships FROM 'seed_data/league_memberships.csv' WITH (FORMAT csv, HEADER true)
\copy learner_achievements FROM 'seed_data/learner_achievements.csv' WITH (FORMAT csv, HEADER true)


-- Update the statistics so PostgreSQL knows how big each table is
ANALYZE;


-- Row count check: the "rows" column must be equal to the "expected" column
-- (expected numbers are from the README)
SELECT 'languages' AS table_name, count(*) AS rows, 10 AS expected FROM languages
UNION ALL SELECT 'courses',              count(*), 11     FROM courses
UNION ALL SELECT 'units',                count(*), 220    FROM units
UNION ALL SELECT 'lessons',              count(*), 1760   FROM lessons
UNION ALL SELECT 'learners',             count(*), 30000  FROM learners
UNION ALL SELECT 'enrollments',          count(*), 37500  FROM enrollments
UNION ALL SELECT 'lesson_attempts',      count(*), 188300 FROM lesson_attempts
UNION ALL SELECT 'daily_activity',       count(*), 189109 FROM daily_activity
UNION ALL SELECT 'league_memberships',   count(*), 28598  FROM league_memberships
UNION ALL SELECT 'achievements',         count(*), 10     FROM achievements
UNION ALL SELECT 'learner_achievements', count(*), 38860  FROM learner_achievements;
