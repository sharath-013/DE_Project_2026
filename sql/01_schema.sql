-- =====================================================
-- 01_schema.sql  (Phase 2, Team T0137)
-- Creates the schema "duolingo" and all 11 tables.
--
-- How to run (on an empty database):
--   psql -d <database> -f sql/01_schema.sql
--
-- Rules we followed:
--  * Only constraints here: PRIMARY KEY, FOREIGN KEY, UNIQUE,
--    NOT NULL, CHECK and DEFAULT.
--  * No extra indexes. PostgreSQL makes indexes for PRIMARY KEY
--    and UNIQUE by itself, and that is all we have in this phase.
--  * A line ending with "VERIFY" has a list of allowed values that
--    we must compare with the real CSV files before loading
--    (commands are in docs/02_schema_design.md, section 6).
--
-- Tables are created parents first, so the foreign keys work.
-- =====================================================

DROP SCHEMA IF EXISTS duolingo CASCADE;
CREATE SCHEMA duolingo;
SET search_path TO duolingo;


-- 1. languages (10 rows)
-- The 2-letter code never changes, so we use it as the primary key.
CREATE TABLE languages (
    language_code CHAR(2)     PRIMARY KEY,
    language_name VARCHAR(50) NOT NULL UNIQUE,
    CONSTRAINT ck_language_code_format CHECK (language_code ~ '^[a-z]{2}$')
);


-- 2. courses (11 rows)
-- A course = the language the learner speaks (from_lang)
-- + the language the learner learns (learning_lang).
-- RESTRICT: a language cannot be deleted while a course uses it.
CREATE TABLE courses (
    course_id     SMALLINT     PRIMARY KEY,
    from_lang     CHAR(2)      NOT NULL REFERENCES languages(language_code) ON DELETE RESTRICT,
    learning_lang CHAR(2)      NOT NULL REFERENCES languages(language_code) ON DELETE RESTRICT,
    title         VARCHAR(100) NOT NULL,
    launched_on   DATE         NOT NULL,
    CONSTRAINT uq_course_pair      UNIQUE (from_lang, learning_lang),   -- one course per language pair
    CONSTRAINT ck_course_diff_lang CHECK (from_lang <> learning_lang)   -- nobody learns the language they speak
);


-- 3. units (220 rows)
-- A course is divided into units. unit_no is the position inside the course.
-- CASCADE: if a course is deleted, its units are deleted too.
CREATE TABLE units (
    unit_id     INTEGER      PRIMARY KEY,
    course_id   SMALLINT     NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    unit_no     SMALLINT     NOT NULL,
    title       VARCHAR(100) NOT NULL,
    cefr_level  VARCHAR(2)   NOT NULL,
    CONSTRAINT uq_unit_in_course UNIQUE (course_id, unit_no),           -- no two units with the same number in a course
    CONSTRAINT ck_unit_no_pos    CHECK (unit_no > 0),
    CONSTRAINT ck_cefr_level     CHECK (cefr_level IN ('A1','A2','B1','B2','C1','C2'))   -- VERIFY
);


-- 4. lessons (1,760 rows)
-- A unit is divided into lessons. lesson_no is the position inside the unit.
CREATE TABLE lessons (
    lesson_id   INTEGER     PRIMARY KEY,
    unit_id     INTEGER     NOT NULL REFERENCES units(unit_id) ON DELETE CASCADE,
    lesson_no   SMALLINT    NOT NULL,
    lesson_type VARCHAR(15) NOT NULL,
    xp_value    SMALLINT    NOT NULL,
    CONSTRAINT uq_lesson_in_unit UNIQUE (unit_id, lesson_no),
    CONSTRAINT ck_lesson_no_pos  CHECK (lesson_no > 0),
    CONSTRAINT ck_lesson_xp_pos  CHECK (xp_value > 0),
    CONSTRAINT ck_lesson_type    CHECK (lesson_type IN ('LEARN','PRACTICE','STORY','REVIEW','TEST'))   -- VERIFY
);


-- 5. learners (30,000 rows)
-- referred_by points to another learner in the same table (self reference).
-- It can be NULL because most learners joined without a referral.
-- SET NULL: if the referrer is deleted, we keep the learner and only clear the link.
CREATE TABLE learners (
    learner_id    INTEGER      PRIMARY KEY,
    username      VARCHAR(30)  NOT NULL UNIQUE,
    email         VARCHAR(100) NOT NULL UNIQUE,
    country_code  CHAR(2)      NOT NULL,
    daily_goal_xp SMALLINT     NOT NULL DEFAULT 10,
    subscription  VARCHAR(5)   NOT NULL DEFAULT 'FREE',
    referred_by   INTEGER      REFERENCES learners(learner_id) ON DELETE SET NULL,
    joined_at     TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ck_username_format  CHECK (username ~ '^[A-Za-z0-9_]{3,30}$'),
    CONSTRAINT ck_email_format     CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT ck_country_format   CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_daily_goal       CHECK (daily_goal_xp IN (10,20,30,50)),   -- VERIFY
    CONSTRAINT ck_subscription     CHECK (subscription IN ('FREE','SUPER','MAX')),
    CONSTRAINT ck_no_self_referral CHECK (referred_by IS NULL OR referred_by <> learner_id)
);


-- 6. enrollments (37,500 rows)
-- Which learner takes which course. A learner can enroll in a course only once,
-- so the primary key is the two columns together.
CREATE TABLE enrollments (
    learner_id  INTEGER     NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    course_id   SMALLINT    NOT NULL REFERENCES courses(course_id)   ON DELETE RESTRICT,
    enrolled_at TIMESTAMPTZ NOT NULL,
    total_xp    INTEGER     NOT NULL DEFAULT 0,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    PRIMARY KEY (learner_id, course_id),
    CONSTRAINT ck_total_xp_nonneg CHECK (total_xp >= 0)
);


-- 7. lesson_attempts (188,300 rows)
-- Every time a learner starts a lesson. This is the biggest table, so attempt_id is BIGINT.
-- completed_at is NULL when the learner quit or has not finished yet.
-- The DEFAULT values are needed because query W01 inserts a row without them.
-- RESTRICT on lesson_id: we keep the history, so a lesson with attempts cannot be deleted.
CREATE TABLE lesson_attempts (
    attempt_id   BIGINT      PRIMARY KEY,
    learner_id   INTEGER     NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    lesson_id    INTEGER     NOT NULL REFERENCES lessons(lesson_id)   ON DELETE RESTRICT,
    started_at   TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    mistakes     SMALLINT    NOT NULL DEFAULT 0,
    hearts_lost  SMALLINT    NOT NULL DEFAULT 0,
    xp_earned    SMALLINT    NOT NULL DEFAULT 0,
    is_perfect   BOOLEAN     NOT NULL DEFAULT FALSE,
    device       VARCHAR(10) NOT NULL,
    CONSTRAINT ck_mistakes_nonneg     CHECK (mistakes >= 0),
    CONSTRAINT ck_hearts_le_mistakes  CHECK (hearts_lost >= 0 AND hearts_lost <= mistakes),   -- hearts lost cannot be more than mistakes
    CONSTRAINT ck_xp_nonneg           CHECK (xp_earned >= 0),
    CONSTRAINT ck_end_after_start     CHECK (completed_at IS NULL OR completed_at >= started_at),
    CONSTRAINT ck_perfect_no_mistakes CHECK (NOT is_perfect OR mistakes = 0),                 -- a perfect lesson has no mistakes
    CONSTRAINT ck_quit_earns_no_xp    CHECK (completed_at IS NOT NULL OR xp_earned = 0),      -- a quit attempt earns no XP
    CONSTRAINT ck_device              CHECK (device IN ('ANDROID','IOS','WEB'))               -- VERIFY
);


-- 8. daily_activity (189,109 rows)
-- One row for each learner for each day, so the key is (learner_id, activity_date).
-- Query W03 uses ON CONFLICT on exactly this key.
CREATE TABLE daily_activity (
    learner_id         INTEGER  NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    activity_date      DATE     NOT NULL,
    xp                 INTEGER  NOT NULL DEFAULT 0,
    lessons_completed  SMALLINT NOT NULL DEFAULT 0,
    used_streak_freeze BOOLEAN  NOT NULL DEFAULT FALSE,
    PRIMARY KEY (learner_id, activity_date),
    CONSTRAINT ck_daily_xp_nonneg  CHECK (xp >= 0),
    CONSTRAINT ck_daily_lessons_ok CHECK (lessons_completed >= 0),
    CONSTRAINT ck_freeze_means_0xp CHECK (NOT used_streak_freeze OR xp = 0)   -- a freeze day has 0 XP
);


-- 9. league_memberships (28,598 rows)
-- One row for each learner for each week. A cohort is a group of about 30 learners.
-- final_rank and result are NULL until the week is closed (query W04 fills them).
CREATE TABLE league_memberships (
    learner_id INTEGER     NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    week_start DATE        NOT NULL,
    tier       VARCHAR(12) NOT NULL,
    cohort_id  INTEGER     NOT NULL,
    weekly_xp  INTEGER     NOT NULL DEFAULT 0,
    final_rank SMALLINT,
    result     VARCHAR(8),
    PRIMARY KEY (learner_id, week_start),
    CONSTRAINT ck_week_is_monday   CHECK (EXTRACT(ISODOW FROM week_start) = 1),   -- weeks start on Monday
    CONSTRAINT ck_tier_format      CHECK (tier ~ '^[A-Z]+$'),                      -- VERIFY the tier names
    CONSTRAINT ck_weekly_xp_nonneg CHECK (weekly_xp >= 0),
    CONSTRAINT ck_rank_range       CHECK (final_rank IS NULL OR final_rank BETWEEN 1 AND 30),
    CONSTRAINT ck_result_values    CHECK (result IS NULL OR result IN ('PROMOTED','STAYED','DEMOTED')),
    CONSTRAINT ck_rank_with_result CHECK ((final_rank IS NULL) = (result IS NULL))   -- rank and result come together
);


-- 10. achievements (10 rows)
-- The list of badges. code is used by query W05 to find a badge.
CREATE TABLE achievements (
    achievement_id SMALLINT    PRIMARY KEY,
    code           VARCHAR(30) NOT NULL UNIQUE,
    name           VARCHAR(60) NOT NULL UNIQUE,
    CONSTRAINT ck_achievement_code CHECK (code ~ '^[A-Z0-9_]+$')
);


-- 11. learner_achievements (38,860 rows)
-- Many-to-many table between learners and achievements.
-- A learner can earn a badge only once, so the key is the two columns together.
CREATE TABLE learner_achievements (
    learner_id     INTEGER     NOT NULL REFERENCES learners(learner_id)         ON DELETE CASCADE,
    achievement_id SMALLINT    NOT NULL REFERENCES achievements(achievement_id) ON DELETE RESTRICT,
    earned_at      TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (learner_id, achievement_id)
);
