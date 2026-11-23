-- =====================================================
-- 08_partitioning.sql  (Phase 5, Team T0137)
-- Partitioning design for lesson_attempts (our biggest table).
--
-- How to run (after sql/01, 02 and 05 on the same database):
--   psql -d <database> -f sql/08_partitioning.sql
--
-- What it does:
--   1. Creates a partitioned copy of the table, called lesson_attempts_p.
--   2. Creates one partition for every month, from 2025-01 to 2026-12.
--   3. Copies all rows from lesson_attempts into it.
--   4. Shows partition pruning with EXPLAIN.
-- The original table lesson_attempts is NOT changed, so the rest of the project
-- keeps working. In a real system we would swap the two names (see the end).
--
-- WHY RANGE on started_at (and not LIST or HASH):
--   * Many queries filter by date: R04 (one day), R17 (one year), R20 (one month),
--     R22 (newest first). With RANGE partitions, PostgreSQL reads only the
--     months it needs. This is called partition pruning.
--   * The data arrives in time order, so new rows go to the newest partition.
--     The old partitions never change, so VACUUM has nothing to do on them.
--   * Old months can be archived or dropped very fast (DETACH / DROP of a
--     partition), instead of a slow DELETE of millions of rows.
--   * HASH on learner_id would help learner queries (R04, R06), but then every date
--     query would have to read all partitions. LIST does not fit, because there is
--     no small fixed list of values.
-- =====================================================

SET search_path TO duolingo;

-- Time zone of this session = India time, the same time zone as the data (+05:30).
-- The month limits of our partitions are in India time. A query like
--   started_at >= '2026-06-30' AND started_at < '2026-07-01'
-- uses the time zone of the session for the two dates. If the session was in UTC
-- (for example a server or Docker container), that day would not match the month
-- limits, and PostgreSQL would also read the neighbour partition.
-- So in the app and in the benchmark the session time zone must be Asia/Kolkata too.
SET timezone TO 'Asia/Kolkata';

DROP TABLE IF EXISTS lesson_attempts_p CASCADE;


-- -----------------------------------------------------
-- 1. The partitioned parent table
-- LIKE copies the columns, DEFAULT values, NOT NULL and the CHECK constraints
-- (hearts_lost <= mistakes, quit attempt earns no XP, ...).
-- -----------------------------------------------------
CREATE TABLE lesson_attempts_p
    (LIKE lesson_attempts INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    PARTITION BY RANGE (started_at);


-- -----------------------------------------------------
-- PRIMARY KEY RULE for partitioned tables:
-- A primary key (or any UNIQUE constraint) on a partitioned table MUST contain
-- the partition column. So attempt_id alone is not allowed, and we use
-- (attempt_id, started_at).
-- Consequence: the database can no longer promise that attempt_id is unique on its
-- own. We keep it unique in practice because attempt_id comes from one sequence
-- in the app. No other table points to lesson_attempts, so no foreign key breaks.
-- -----------------------------------------------------
ALTER TABLE lesson_attempts_p ADD PRIMARY KEY (attempt_id, started_at);

-- Foreign keys are allowed on partitioned tables (same rules as before)
ALTER TABLE lesson_attempts_p
    ADD CONSTRAINT fk_attempts_p_learner FOREIGN KEY (learner_id) REFERENCES learners(learner_id) ON DELETE CASCADE;
ALTER TABLE lesson_attempts_p
    ADD CONSTRAINT fk_attempts_p_lesson  FOREIGN KEY (lesson_id)  REFERENCES lessons(lesson_id)   ON DELETE RESTRICT;


-- -----------------------------------------------------
-- 2. One partition for every month
-- The limits include the time zone +05:30 (India time). Without it, PostgreSQL
-- would use the time zone of the session that runs this file, and the month
-- limits could move by some hours.
-- The upper limit is NOT included in a partition: [FROM, TO).
--
-- Example of what the loop below creates for January 2025:
--   CREATE TABLE lesson_attempts_p_2025_01 PARTITION OF lesson_attempts_p
--       FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
-- -----------------------------------------------------
DO $$
DECLARE
    m date := DATE '2025-01-01';
BEGIN
    WHILE m < DATE '2027-01-01' LOOP
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF lesson_attempts_p FOR VALUES FROM (%L) TO (%L)',
            'lesson_attempts_p_' || to_char(m, 'YYYY_MM'),
            m::text || ' 00:00:00+05:30',
            (m + INTERVAL '1 month')::date::text || ' 00:00:00+05:30');
        m := (m + INTERVAL '1 month')::date;
    END LOOP;
END $$;

-- A DEFAULT partition catches every row that does not fit in a month above
-- (for example a row from 2027 or from before 2025). Without it such an
-- INSERT would fail with an error.
CREATE TABLE lesson_attempts_p_default PARTITION OF lesson_attempts_p DEFAULT;


-- -----------------------------------------------------
-- 3. Indexes: the same 3 indexes as in sql/05_indexes.sql.
-- An index created on the parent is created on every partition automatically.
-- Every partition has its own small index, so they are quick to build and to maintain.
-- -----------------------------------------------------
CREATE INDEX idx_attempts_p_learner_started
    ON lesson_attempts_p (learner_id, started_at) INCLUDE (xp_earned);
CREATE INDEX idx_attempts_p_lesson
    ON lesson_attempts_p (lesson_id) INCLUDE (mistakes, hearts_lost, completed_at);
CREATE INDEX idx_attempts_p_started_desc
    ON lesson_attempts_p (started_at DESC) INCLUDE (attempt_id, learner_id, lesson_id, xp_earned);


-- -----------------------------------------------------
-- 4. Copy the data and refresh statistics
-- (We copy after creating the partitions. If a row had no partition and there was
-- no DEFAULT partition, this INSERT would fail.)
-- -----------------------------------------------------
INSERT INTO lesson_attempts_p SELECT * FROM lesson_attempts;
VACUUM (ANALYZE) lesson_attempts_p;

-- Check: both tables must have the same number of rows
SELECT (SELECT count(*) FROM lesson_attempts)   AS rows_original,
       (SELECT count(*) FROM lesson_attempts_p) AS rows_partitioned;

-- Check: rows in every partition (the DEFAULT partition should be empty)
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM lesson_attempts_p
GROUP BY 1
ORDER BY 1;


-- =====================================================
-- 5. Partition pruning with EXPLAIN
-- COSTS OFF keeps the output short, so we can see which partitions are read.
-- Look for the lines "Scan on lesson_attempts_p_YYYY_MM".
-- =====================================================

-- 5a. One day (like R04): we expect ONE partition (2026-06)
EXPLAIN (COSTS OFF)
SELECT sum(xp_earned)
FROM lesson_attempts_p
WHERE started_at >= '2026-06-30' AND started_at < '2026-07-01';

-- 5b. One month (like R20): we expect ONE partition (2026-06)
EXPLAIN (COSTS OFF)
SELECT started_at::date AS day, sum(xp_earned)
FROM lesson_attempts_p
WHERE started_at >= '2026-06-01' AND started_at < '2026-07-01'
GROUP BY 1;

-- 5c. One year (like R17): we expect the 12 partitions of 2026 only
EXPLAIN (COSTS OFF)
SELECT device, count(*)
FROM lesson_attempts_p
WHERE completed_at IS NOT NULL
  AND started_at >= '2026-01-01' AND started_at < '2027-01-01'
GROUP BY device;

-- 5d. NO date filter (like R08): there is nothing to prune, so ALL partitions are read.
-- This shows that partitioning does not help every query.
EXPLAIN (COSTS OFF)
SELECT count(*) FROM lesson_attempts_p;

-- 5e. The old way of writing a date filter (a function on the column).
-- PostgreSQL cannot use it for pruning, so ALL partitions are read.
-- This is one more reason for the rewrites in sql/06_optimized_queries.sql.
EXPLAIN (COSTS OFF)
SELECT sum(xp_earned)
FROM lesson_attempts_p
WHERE DATE(started_at) = '2026-06-30';


-- =====================================================
-- 6. Archiving an old month (this is why we chose RANGE partitions)
-- DETACH makes the partition a normal table, instantly. We can then dump it to
-- cold storage and drop it. Run it by hand, not as part of this file:
--
--   ALTER TABLE lesson_attempts_p DETACH PARTITION lesson_attempts_p_2025_01;
--   -- pg_dump -t duolingo.lesson_attempts_p_2025_01 ...   (copy to cold storage)
--   DROP TABLE lesson_attempts_p_2025_01;
--
-- Create next year's partitions before the year starts, or new rows go to the
-- DEFAULT partition and the DEFAULT partition becomes big.
--
-- To use the partitioned table in production (we do NOT do this here), swap the
-- names in one transaction:
--   BEGIN;
--   ALTER TABLE lesson_attempts   RENAME TO lesson_attempts_old;
--   ALTER TABLE lesson_attempts_p RENAME TO lesson_attempts;
--   COMMIT;
-- =====================================================
