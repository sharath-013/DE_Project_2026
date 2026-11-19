-- =====================================================
-- 06_optimized_queries.sql  (Phase 4, Team T0137)
-- Same 30 queries as queries/workload_30.sql.
-- We changed ONLY these 8 queries: R04, R10, R13, R16, R17, R19, R20, R23.
-- The other 22 are copied without change (they get faster only because of the
-- indexes in sql/05_indexes.sql, or they cannot get much faster).
--
-- What we changed:
--  R04, R10, R17, R20: replaced a function on a column (DATE(), EXTRACT(), ::date)
--      with a plain date range, so an index can be used.
--  R13: replaced NOT IN with NOT EXISTS. This also FIXES a wrong answer (the old query
--      returned no rows because referred_by contains NULL). The result is different on purpose.
--  R16: ILIKE became lower(username) LIKE, to match the index idx_learners_username_lower.
--  R19: two subqueries for every lesson became one join with a group.
--  R23: count(DISTINCT) over a join became a count with EXISTS.
--
-- To see exactly what changed, run:
--   diff queries/workload_30.sql sql/06_optimized_queries.sql
-- Proof that the results are the same: sql/07_verify_results.sql
-- =====================================================

-- @R01
SELECT u.unit_no, u.title, u.cefr_level, l.lesson_no, l.lesson_type, l.xp_value
FROM courses c
JOIN units u   ON u.course_id = c.course_id
JOIN lessons l ON l.unit_id = u.unit_id
WHERE c.from_lang = 'en' AND c.learning_lang = 'es'
ORDER BY u.unit_no, l.lesson_no;

-- @R02
SELECT c.title, e.total_xp, e.enrolled_at, e.is_active
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
WHERE e.learner_id = 1042
ORDER BY e.total_xp DESC;

-- @R03
WITH days AS (
    SELECT activity_date,
           activity_date - (row_number() OVER (ORDER BY activity_date))::int AS grp
    FROM daily_activity
    WHERE learner_id = 1042 AND activity_date <= '2026-06-30'
)
SELECT count(*) AS streak_days, min(activity_date) AS streak_started
FROM days
WHERE grp = (SELECT grp FROM days WHERE activity_date = '2026-06-30');

-- @R04
SELECT l.daily_goal_xp, coalesce(sum(a.xp_earned), 0) AS xp_today
FROM learners l
LEFT JOIN lesson_attempts a ON a.learner_id = l.learner_id
                           AND a.started_at >= '2026-06-30' AND a.started_at < '2026-07-01'
WHERE l.learner_id = 1042
GROUP BY l.daily_goal_xp;

-- @R05
SELECT lm.learner_id, le.username, lm.weekly_xp,
       RANK() OVER (ORDER BY lm.weekly_xp DESC) AS position
FROM league_memberships lm
JOIN learners le ON le.learner_id = lm.learner_id
WHERE lm.week_start = '2026-06-29'
  AND lm.cohort_id = (SELECT cohort_id FROM league_memberships WHERE learner_id = 1042 AND week_start = '2026-06-29')
ORDER BY position;

-- @R06
SELECT l.lesson_id, u.unit_no, l.lesson_no, l.lesson_type
FROM units u
JOIN lessons l ON l.unit_id = u.unit_id
WHERE u.course_id = 1
  AND NOT EXISTS (SELECT 1 FROM lesson_attempts a
                  WHERE a.learner_id = 1042 AND a.lesson_id = l.lesson_id AND a.completed_at IS NOT NULL)
ORDER BY u.unit_no, l.lesson_no
LIMIT 1;

-- @R07
SELECT l.lesson_id, u.unit_no, l.lesson_no, count(*) AS attempts, round(avg(a.mistakes), 2) AS avg_mistakes
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
JOIN units u   ON u.unit_id = l.unit_id
WHERE u.course_id = 1
GROUP BY l.lesson_id, u.unit_no, l.lesson_no
HAVING count(*) >= 100
ORDER BY avg_mistakes DESC
LIMIT 20;

-- @R08
SELECT l.lesson_type, count(*) AS attempts,
       round(100.0 * count(*) FILTER (WHERE a.completed_at IS NULL) / count(*), 2) AS quit_pct
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
GROUP BY l.lesson_type
ORDER BY quit_pct DESC;

-- @R09
SELECT activity_date, count(*) AS active_learners
FROM daily_activity
WHERE xp > 0
  AND activity_date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY activity_date
ORDER BY activity_date;

-- @R10
SELECT l.subscription, count(*) AS freezes_used
FROM daily_activity d
JOIN learners l ON l.learner_id = d.learner_id
WHERE d.used_streak_freeze
  AND d.activity_date >= '2026-01-01' AND d.activity_date < '2027-01-01'
GROUP BY l.subscription
ORDER BY freezes_used DESC;

-- @R11
SELECT learner_id, email, subscription, daily_goal_xp
FROM learners
WHERE username = 'Karan_xVerma1042';

-- @R12
SELECT a.code, a.name, la.earned_at
FROM learner_achievements la
JOIN achievements a ON a.achievement_id = la.achievement_id
WHERE la.learner_id = 1042
ORDER BY la.earned_at DESC;

-- @R13
SELECT l.learner_id, l.username
FROM learners l
WHERE NOT EXISTS (SELECT 1 FROM learners r WHERE r.referred_by = l.learner_id);

-- @R14
SELECT tier, count(*) AS memberships,
       round(100.0 * count(*) FILTER (WHERE result = 'PROMOTED') / count(*), 1) AS promoted_pct,
       round(100.0 * count(*) FILTER (WHERE result = 'DEMOTED') / count(*), 1) AS demoted_pct
FROM league_memberships
WHERE week_start BETWEEN '2026-06-01' AND '2026-06-22'
GROUP BY tier
ORDER BY tier;

-- @R15
SELECT count(*) AS joined_jan,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM daily_activity d WHERE d.learner_id = l.learner_id
                                      AND d.activity_date >= '2026-06-01' AND d.xp > 0)) AS active_june
FROM learners l
WHERE l.joined_at >= '2026-01-01' AND l.joined_at < '2026-02-01';

-- @R16
SELECT learner_id, username, country_code
FROM learners
WHERE lower(username) LIKE 'karan%'
ORDER BY username
LIMIT 20;

-- @R17
SELECT device, count(*) AS completed,
       round(100.0 * count(*) FILTER (WHERE is_perfect) / count(*), 2) AS perfect_pct
FROM lesson_attempts
WHERE completed_at IS NOT NULL
  AND started_at >= '2026-01-01' AND started_at < '2027-01-01'
GROUP BY device
ORDER BY perfect_pct DESC;

-- @R18
SELECT c.title, count(*) AS learners, count(*) FILTER (WHERE e.enrolled_at >= '2026-01-01') AS new_in_2026
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
GROUP BY c.title
ORDER BY learners DESC;

-- @R19
SELECT l.lesson_id, u.unit_no, l.lesson_no,
       count(a.lesson_id) FILTER (WHERE a.completed_at IS NOT NULL) AS completions,
       round(avg(a.mistakes), 2) AS avg_mistakes
FROM lessons l
JOIN units u ON u.unit_id = l.unit_id
LEFT JOIN lesson_attempts a ON a.lesson_id = l.lesson_id
WHERE u.course_id = 1
GROUP BY l.lesson_id, u.unit_no, l.lesson_no
ORDER BY u.unit_no, l.lesson_no;

-- @R20
SELECT day, xp, sum(xp) OVER (ORDER BY day) AS running_xp
FROM (
    SELECT started_at::date AS day, sum(xp_earned) AS xp
    FROM lesson_attempts
    WHERE started_at >= '2026-06-01' AND started_at < '2026-07-01'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
SELECT d.learner_id
FROM daily_activity d
WHERE d.activity_date BETWEEN '2026-06-23' AND '2026-06-29'
GROUP BY d.learner_id
HAVING count(*) = 7
   AND NOT EXISTS (SELECT 1 FROM daily_activity t WHERE t.learner_id = d.learner_id AND t.activity_date = '2026-06-30')
ORDER BY d.learner_id;

-- @R22
SELECT attempt_id, learner_id, lesson_id, started_at, xp_earned
FROM lesson_attempts
ORDER BY started_at DESC
OFFSET 100000
LIMIT 25;

-- @R23
SELECT l.subscription, count(*) AS active_paid_learners
FROM learners l
WHERE l.country_code = 'IN' AND l.subscription IN ('SUPER', 'MAX')
  AND EXISTS (SELECT 1 FROM daily_activity d
              WHERE d.learner_id = l.learner_id AND d.activity_date >= '2026-06-24' AND d.xp > 0)
GROUP BY l.subscription;

-- @R24
SELECT u.cefr_level, count(*) AS attempts, round(avg(a.hearts_lost), 2) AS avg_hearts_lost
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
JOIN units u   ON u.unit_id = l.unit_id
GROUP BY u.cefr_level
ORDER BY u.cefr_level;

-- @R25
SELECT le.country_code, EXTRACT(HOUR FROM a.started_at) AS hour, count(*) AS lessons
FROM lesson_attempts a
JOIN learners le ON le.learner_id = a.learner_id
GROUP BY 1, 2
ORDER BY 1, 2;

-- @W01
INSERT INTO lesson_attempts (attempt_id, learner_id, lesson_id, started_at, device)
VALUES (90000001, 1042, 1, '2026-07-01 07:00:00+05:30', 'ANDROID');

-- @W02
UPDATE lesson_attempts
SET completed_at = started_at + interval '4 minutes', mistakes = 2, hearts_lost = 2, xp_earned = 10
WHERE attempt_id = (SELECT max(attempt_id) FROM lesson_attempts
                    WHERE completed_at IS NULL AND started_at >= '2026-06-30' AND started_at < '2026-07-01');

-- @W03
INSERT INTO daily_activity (learner_id, activity_date, xp, lessons_completed)
VALUES (1042, '2026-07-01', 20, 1)
ON CONFLICT (learner_id, activity_date)
DO UPDATE SET xp = daily_activity.xp + EXCLUDED.xp,
              lessons_completed = daily_activity.lessons_completed + EXCLUDED.lessons_completed;

-- @W04
UPDATE league_memberships lm
SET final_rank = r.rnk,
    result = CASE WHEN r.rnk <= 7 THEN 'PROMOTED' WHEN r.rnk >= 26 THEN 'DEMOTED' ELSE 'STAYED' END
FROM (SELECT learner_id, week_start,
             row_number() OVER (PARTITION BY cohort_id ORDER BY weekly_xp DESC, learner_id) AS rnk
      FROM league_memberships WHERE week_start = '2026-06-29') r
WHERE lm.learner_id = r.learner_id AND lm.week_start = r.week_start;

-- @W05
INSERT INTO learner_achievements (learner_id, achievement_id, earned_at)
SELECT e.learner_id, (SELECT achievement_id FROM achievements WHERE code = 'XP_100'), '2026-07-01 00:00:00+05:30'
FROM enrollments e
GROUP BY e.learner_id
HAVING sum(e.total_xp) >= 100
ON CONFLICT (learner_id, achievement_id) DO NOTHING;
