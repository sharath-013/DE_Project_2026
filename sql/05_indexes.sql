-- =====================================================
-- 05_indexes.sql  (Phase 4, Team T0137)
-- The indexes we added to make the 30 queries faster.
--
-- How to run (once, after loading the data):
--   psql -d <database> -f sql/05_indexes.sql
--
-- Before this file the database only had the automatic indexes from
-- PRIMARY KEY and UNIQUE (see docs/02_schema_design.md, section 9).
--
-- Rules we followed:
--  * Every index has a comment: which queries it helps and why we chose
--    this type and this column order.
--  * Equality columns come first, then range or sort columns.
--  * We kept the number of indexes small, because every index makes
--    INSERT and UPDATE slower (we measure this in docs/04_optimization_report.md).
--  * Query numbers (R04, W01, ...) are from queries/workload_30.sql.
-- =====================================================

SET search_path TO duolingo;


-- =====================================================
-- Table: lesson_attempts (188,300 rows, our biggest table)
-- =====================================================

-- 1. idx_attempts_learner_started
-- Helps: R04 (today's XP of one learner), R06 (lessons a learner already completed).
-- Why: both queries look at ONE learner, so learner_id comes first (equality).
--      started_at comes second so the "one day" range is read in order.
--      A learner has only about 6 attempts, so R06 can check them all quickly.
--      INCLUDE (xp_earned) lets R04 read the index only, without visiting the table.
-- Type: B-tree, composite, covering (INCLUDE).
CREATE INDEX IF NOT EXISTS idx_attempts_learner_started
    ON lesson_attempts (learner_id, started_at) INCLUDE (xp_earned);


-- 2. idx_attempts_lesson
-- Helps: R07 and R19 (many attempts of the lessons of ONE course),
--        R08 and R24 (every attempt joined with its lesson).
-- Why: all four queries join lesson_attempts to lessons using lesson_id, so we
--      index lesson_id. INCLUDE (mistakes, hearts_lost, completed_at) holds the
--      other columns these queries read, so the table is not visited.
--      For R07 and R19 only about 160 of 1,760 lessons are needed, so most of
--      the index is skipped.
--      R08 and R24 must read every attempt anyway, so we expect only a small gain.
-- Type: B-tree, covering (INCLUDE).
CREATE INDEX IF NOT EXISTS idx_attempts_lesson
    ON lesson_attempts (lesson_id) INCLUDE (mistakes, hearts_lost, completed_at);


-- 3. idx_attempts_started_desc
-- Helps: R22 (newest attempts first, skip 100,000 rows), R20 (XP per day in June 2026).
-- Why: R22 sorts by started_at DESC, so an index in the same order removes the sort.
--      R20 needs one month of started_at values, which is a range on the first column.
--      INCLUDE holds every column these queries select, so no table visits are needed.
-- Type: B-tree, descending, covering (INCLUDE).
CREATE INDEX IF NOT EXISTS idx_attempts_started_desc
    ON lesson_attempts (started_at DESC) INCLUDE (attempt_id, learner_id, lesson_id, xp_earned);


-- =====================================================
-- Table: daily_activity (189,109 rows)
-- =====================================================

-- 4. idx_daily_date_cover
-- Helps: R09 (daily active learners in June), R21 (learners active 23 to 29 June),
--        R23 (paid learners active in the last 7 days).
-- Why: the primary key starts with learner_id, so it cannot help when we filter by
--      date only. These queries filter a range of dates first, so activity_date
--      comes first. INCLUDE (learner_id, xp) holds the other columns they use.
-- Type: B-tree, covering (INCLUDE).
CREATE INDEX IF NOT EXISTS idx_daily_date_cover
    ON daily_activity (activity_date) INCLUDE (learner_id, xp);


-- 5. idx_daily_freeze
-- Helps: R10 (streak freezes used in 2026).
-- Why: only a few days are freeze days, so a partial index is very small.
--      It stores only the rows where used_streak_freeze is true.
-- Type: B-tree, partial.
CREATE INDEX IF NOT EXISTS idx_daily_freeze
    ON daily_activity (activity_date) INCLUDE (learner_id)
    WHERE used_streak_freeze;


-- =====================================================
-- Table: learners (30,000 rows)
-- =====================================================

-- 6. idx_learners_username_lower
-- Helps: R16 (friend search, username starts with "Karan").
-- Why: ILIKE cannot use the normal UNIQUE index on username. We index
--      lower(username) and rewrite the query to use lower(username) LIKE 'karan%'.
--      usernames only have letters, digits and underscore (CHECK in the schema),
--      so the result is the same.
--      text_pattern_ops lets a B-tree answer LIKE 'prefix%'.
-- Type: B-tree, expression index.
CREATE INDEX IF NOT EXISTS idx_learners_username_lower
    ON learners (lower(username) text_pattern_ops);


-- 7. idx_learners_joined_at
-- Helps: R15 (learners who joined in January 2026).
-- Why: the query filters a range of joined_at, and only a small share of learners joined in that month.
-- Type: B-tree.
CREATE INDEX IF NOT EXISTS idx_learners_joined_at
    ON learners (joined_at);


-- 8. idx_learners_referred_by
-- Helps: R13 (learners who have not referred anyone). The fixed query uses
--        NOT EXISTS and needs a fast check "does anyone have referred_by = this learner?".
-- Why: most learners have referred_by = NULL, and we never search for NULL,
--      so a partial index (only rows where referred_by is not NULL) is small.
-- Type: B-tree, partial.
CREATE INDEX IF NOT EXISTS idx_learners_referred_by
    ON learners (referred_by)
    WHERE referred_by IS NOT NULL;


-- =====================================================
-- Table: league_memberships (28,598 rows)
-- =====================================================

-- 9. idx_league_week_cohort
-- Helps: R05 (leaderboard of one cohort in one week), R14 (rates for 4 weeks),
--        W04 (close the week: rank every cohort of one week).
-- Why: all three filter by week_start first (equality or range), and R05 and W04
--      then group by cohort_id. So the order is (week_start, cohort_id).
--      INCLUDE (learner_id, weekly_xp) holds the columns R05 reads.
--      We did NOT include final_rank or result, because W04 updates them,
--      and updating an indexed column makes the update slower.
-- Type: B-tree, composite, covering (INCLUDE).
CREATE INDEX IF NOT EXISTS idx_league_week_cohort
    ON league_memberships (week_start, cohort_id) INCLUDE (learner_id, weekly_xp);


-- =====================================================
-- After creating indexes: VACUUM and ANALYZE
-- =====================================================
-- VACUUM builds the visibility map. Without it, a "covering" index cannot give an
-- Index Only Scan, because PostgreSQL still has to check the table.
-- ANALYZE refreshes the statistics, so the planner knows about the new indexes.
VACUUM (ANALYZE);


-- =====================================================
-- Index storage: size of each index compared with its table
-- (we paste the result into docs/04_optimization_report.md)
-- =====================================================
SELECT s.relname                                    AS table_name,
       s.indexrelname                               AS index_name,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
       pg_size_pretty(pg_relation_size(s.relid))      AS table_size
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'duolingo' AND s.indexrelname LIKE 'idx\_%'
ORDER BY pg_relation_size(s.indexrelid) DESC;
