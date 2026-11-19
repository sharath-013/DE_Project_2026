SET search_path TO duolingo;

-- R04: Equality on learner_id first, range on started_at second; INCLUDE xp_earned for Index Only Scan
CREATE INDEX IF NOT EXISTS idx_attempts_learner_started
    ON lesson_attempts (learner_id, started_at)
    INCLUDE (xp_earned);

-- R06: Partial index on completed attempts only; accelerates NOT EXISTS lookup per (learner_id, lesson_id)
CREATE INDEX IF NOT EXISTS idx_attempts_completed_learner_lesson
    ON lesson_attempts (learner_id, lesson_id)
    WHERE completed_at IS NOT NULL;

-- R07, R08, R19, R24: Covering index on lesson_id for attempt counts, completions, mistakes, and hearts_lost
CREATE INDEX IF NOT EXISTS idx_attempts_lesson_stats
    ON lesson_attempts (lesson_id)
    INCLUDE (completed_at, mistakes, hearts_lost);

-- R17, R20, R22: Time-ordered index on started_at; supports sargable date ranges and DESC pagination without sort
CREATE INDEX IF NOT EXISTS idx_attempts_started_at
    ON lesson_attempts (started_at DESC)
    INCLUDE (attempt_id, learner_id, lesson_id, completed_at, is_perfect, device, xp_earned);

-- W02: Partial index on unfinished attempts only so finding max(attempt_id) on a given day avoids scanning completed rows
CREATE INDEX IF NOT EXISTS idx_attempts_unfinished_started
    ON lesson_attempts (started_at, attempt_id)
    WHERE completed_at IS NULL;

-- R09, R21, R23: Leads with activity_date (which is trailing in PK) for date-range active learner scans
CREATE INDEX IF NOT EXISTS idx_daily_activity_date_learner
    ON daily_activity (activity_date, learner_id)
    INCLUDE (xp);

-- R10: Partial index on streak freeze rows only (rare boolean flag) ordered by activity_date
CREATE INDEX IF NOT EXISTS idx_daily_activity_freeze_date
    ON daily_activity (activity_date, learner_id)
    WHERE used_streak_freeze;

-- R05, W04: Equality on (week_start, cohort_id) followed by pre-sorted weekly_xp DESC for instant 30-row leaderboards
CREATE INDEX IF NOT EXISTS idx_league_week_cohort_xp
    ON league_memberships (week_start, cohort_id, weekly_xp DESC)
    INCLUDE (learner_id);

-- R14: Leads with week_start and tier, including result for Index Only Scan over the 4-week window
CREATE INDEX IF NOT EXISTS idx_league_week_tier_result
    ON league_memberships (week_start, tier)
    INCLUDE (result);

-- R13: Partial index on non-null referred_by values for fast anti-join lookup of users with zero referrals
CREATE INDEX IF NOT EXISTS idx_learners_referred_by
    ON learners (referred_by)
    WHERE referred_by IS NOT NULL;

-- R15: Range scan on joined_at for January 2026 cohort retention check
CREATE INDEX IF NOT EXISTS idx_learners_joined_at
    ON learners (joined_at)
    INCLUDE (learner_id);

-- R16: Expression index with varchar_pattern_ops for case-insensitive prefix search (lower(username) LIKE 'karan%')
CREATE INDEX IF NOT EXISTS idx_learners_lower_username_pattern
    ON learners (lower(username) varchar_pattern_ops)
    INCLUDE (learner_id, username, country_code);

-- R23, R25: Filters paid Indian learners (country_code, subscription) and covers learner_id for joins
CREATE INDEX IF NOT EXISTS idx_learners_country_sub
    ON learners (country_code, subscription)
    INCLUDE (learner_id);

-- R18: Leads with course_id (trailing in PK) and covers enrolled_at for course popularity aggregation
CREATE INDEX IF NOT EXISTS idx_enrollments_course_enrolled
    ON enrollments (course_id)
    INCLUDE (enrolled_at);

-- W05: Covers total_xp per learner_id so summing XP across courses uses an Index Only Scan
CREATE INDEX IF NOT EXISTS idx_enrollments_learner_xp
    ON enrollments (learner_id)
    INCLUDE (total_xp);

VACUUM ANALYZE;
