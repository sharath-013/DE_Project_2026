# Phase 3: Baseline Query Timings

**Team:** T0137 · **Database:** PostgreSQL (`duolingo` schema, Phase 2 constraints only)  
**Method:** 3 runs per query via `./benchmarks/run_benchmark.sh duolingo_db baseline` (`EXPLAIN (ANALYZE, BUFFERS)`), writes rolled back inside `BEGIN; ... ROLLBACK;`.

## Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Course path: units and lessons of the Spanish course for English speakers, in order | READ | 0.449 | 0.422 | 0.390 | 0.535 |
| R02: Home screen: learner 1042's courses with total XP | READ | 0.182 | 0.184 | 0.170 | 0.193 |
| R03: Streak counter: learner 1042's current streak (consecutive days up to 30 June 2026, freezes count) | READ | 0.369 | 0.347 | 0.343 | 0.418 |
| R04: Daily goal ring: XP learner 1042 earned on 30 June 2026 vs their daily goal | READ | 13.610 | 12.592 | 10.753 | 17.485 |
| R05: Leagues tab: leaderboard of learner 1042's cohort for the week starting 29 June 2026 | READ | 4.303 | 4.332 | 4.238 | 4.338 |
| R06: "Start" button: the first lesson of learner 1042's Spanish course they have not completed yet | READ | 17.172 | 16.682 | 13.588 | 21.245 |
| R07: Curriculum team: lessons of the Spanish course with the most mistakes per attempt (100+ attempts) | READ | 34.371 | 34.293 | 33.596 | 35.223 |
| R08: Product analytics: quit rate per lesson type | READ | 31.893 | 31.959 | 31.291 | 32.430 |
| R09: Growth: daily active learners in June 2026 | READ | 8.681 | 8.668 | 8.591 | 8.784 |
| R10: Monetisation: streak freezes used per subscription tier in 2026 | READ | 8.258 | 8.263 | 8.245 | 8.265 |
| R11: Sign-in by username | READ | 0.051 | 0.052 | 0.047 | 0.053 |
| R12: Profile: learner 1042's achievements, newest first | READ | 0.132 | 0.133 | 0.127 | 0.136 |
| R13: Referral programme: learners who have not referred anyone yet | READ | 15.900 | 14.396 | 13.010 | 20.295 |
| R14: Leagues team: promotion and demotion rates per tier over the last 4 completed weeks | READ | 5.368 | 4.988 | 4.930 | 6.186 |
| R15: Retention: learners who joined in January 2026 and were still active in June 2026 | READ | 5.104 | 5.315 | 3.938 | 6.058 |
| R16: Friends: search learners by username starting with "Karan" | READ | 11.254 | 11.304 | 9.577 | 12.882 |
| R17: Product analytics: perfect-lesson rate per device in 2026 | READ | 28.954 | 26.685 | 26.643 | 33.533 |
| R18: Course popularity: enrollments per course, and how many started in 2026 | READ | 11.236 | 11.208 | 11.092 | 11.408 |
| R19: Curriculum report: completions and average mistakes of every lesson in the Spanish course | READ | 3123.027 | 3140.648 | 3086.524 | 3141.908 |
| R20: Growth: XP earned per day across the platform and running total, June 2026 | READ | 14.870 | 14.928 | 14.737 | 14.946 |
| R21: Streak reminders: learners active every day from 23 to 29 June but not yet on 30 June | READ | 4.706 | 4.688 | 4.686 | 4.744 |
| R22: Support console: all lesson attempts, newest first, page 4,001 (25 per page) | READ | 64.807 | 65.659 | 63.092 | 65.670 |
| R23: Monetisation: Super and Max learners in India who were active in the last 7 days of June 2026 | READ | 12.365 | 12.124 | 11.510 | 13.461 |
| R24: Curriculum team: average hearts lost per lesson, by CEFR level | READ | 45.460 | 44.980 | 44.665 | 46.736 |
| R25: Notifications team: lessons started per hour of the day, per country | READ | 228.265 | 220.883 | 216.516 | 247.397 |
| W01: Lesson start: learner 1042 starts lesson 1 | WRITE | 0.828 | 0.834 | 0.785 | 0.865 |
| W02: Lesson end: finish the most recent unfinished attempt of 30 June 2026 with 2 mistakes | WRITE | 1.425 | 1.411 | 1.171 | 1.692 |
| W03: Daily activity: add 20 XP to learner 1042's 1 July 2026 (creating the row if needed) | WRITE | 2.112 | 2.122 | 2.080 | 2.133 |
| W04: Weekly league close (week of 29 June 2026): rank everyone in their cohort and set promotion results | WRITE | 15.533 | 14.331 | 12.438 | 19.830 |
| W05: Achievements catch-up: award the "100 XP" badge to every learner who has 100+ XP but not the badge | WRITE | 69.236 | 69.447 | 68.265 | 69.997 |
| **Total (sum of all 30)** | | **3779.921** | **3783.878** | **3707.038** | **3848.846** |

## Scan Types & Explanations

- **R01** (`Seq Scan on units | Seq Scan on courses | Index Scan using uq_lesson_in_unit on lessons`): Fast because lookup tables are tiny (11 courses, 220 units, 1,760 lessons) and `lessons` uses `uq_lesson_in_unit`.
- **R02** (`Index Scan using enrollments_pkey on enrollments | Seq Scan on courses`): Fast because `learner_id` is the leading column of `enrollments_pkey (learner_id, course_id)`.
- **R03** (`Index Only Scan using daily_activity_pkey on daily_activity`): Fast because `daily_activity_pkey (learner_id, activity_date)` resolves learner 1042's dates via an Index Only Scan.
- **R04** (`Index Scan using learners_pkey on learners | Seq Scan on lesson_attempts`): Slow because `lesson_attempts` has no index on `(learner_id, started_at)` and `DATE(started_at)` forces a full Seq Scan of 188,300 rows.
- **R05** (`Index Scan using league_memberships_pkey on league_memberships | Seq Scan on league_memberships | Index Scan using learners_pkey on learners`): Moderately slow because `week_start` is the trailing column of `league_memberships_pkey`, forcing a Seq Scan of 28,598 rows to filter `cohort_id`.
- **R06** (`Index Scan using uq_unit_in_course on units | Index Scan using uq_lesson_in_unit on lessons | Seq Scan on lesson_attempts`): Slow because `lesson_attempts` lacks an index on `(learner_id, lesson_id)`, causing a Seq Scan over 188,300 rows for the `NOT EXISTS` check.
- **R07** (`Seq Scan on lesson_attempts | Seq Scan on lessons | Seq Scan on units`): Slow because `lesson_id` is unindexed in `lesson_attempts`, scanning all 188,300 rows before joining and grouping.
- **R08** (`Seq Scan on lesson_attempts | Seq Scan on lessons`): Slow because all 188,300 rows of `lesson_attempts` must be sequentially scanned to compute quit rates per `lesson_type`.
- **R09** (`Seq Scan on daily_activity`): Slow because `activity_date` is the second column of `daily_activity_pkey`, forcing a full Seq Scan of 189,109 rows.
- **R10** (`Seq Scan on daily_activity | Index Scan using learners_pkey on learners`): Slow because `used_streak_freeze` and `EXTRACT(YEAR FROM activity_date)` have no index, scanning all 189,109 `daily_activity` rows.
- **R11** (`Index Scan using learners_username_key on learners`): Fast because `username = 'Karan_xVerma1042'` is an exact lookup on `learners_username_key`.
- **R12** (`Index Scan using learner_achievements_pkey on learner_achievements | Seq Scan on achievements`): Fast because `learner_id` leads `learner_achievements_pkey` and returns at most 10 rows.
- **R13** (`Seq Scan on learners`): Slow and returns 0 rows (wrong result) because `referred_by` is unindexed and `NOT IN` evaluates to UNKNOWN when `referred_by` contains `NULL`.
- **R14** (`Seq Scan on league_memberships`): Slow because `week_start` is not the leading key of `league_memberships_pkey`, forcing a Seq Scan of 28,598 rows.
- **R15** (`Seq Scan on learners | Index Scan using daily_activity_pkey on daily_activity`): Moderately slow because `learners.joined_at` is unindexed, requiring a full Seq Scan of 30,000 learners.
- **R16** (`Index Scan using learners_username_key on learners`): Moderately slow because case-insensitive `ILIKE 'karan%'` cannot use a standard B-tree range seek on `learners_username_key`.
- **R17** (`Seq Scan on lesson_attempts`): Slow because `EXTRACT(YEAR FROM started_at)` is non-sargable and `lesson_attempts` has no index on `(started_at, device)`.
- **R18** (`Seq Scan on enrollments | Seq Scan on courses`): Slow because `course_id` is the trailing column of `enrollments_pkey` and `enrolled_at` is unindexed across 37,500 rows.
- **R19** (`Index Scan using uq_unit_in_course on units | Index Scan using uq_lesson_in_unit on lessons | Seq Scan on lesson_attempts`): Very slow (3,086 ms) because two correlated subqueries execute a Seq Scan of 188,300 `lesson_attempts` rows for every Spanish lesson (~320 scans total).
- **R20** (`Seq Scan on lesson_attempts`): Slow because `started_at::date` prevents index usage and forces a full Seq Scan of 188,300 `lesson_attempts` rows.
- **R21** (`Index Only Scan using daily_activity_pkey on daily_activity`): Moderately fast via Index Only Scan on `daily_activity_pkey`, though it still scans all 189,109 index entries since `activity_date` is the trailing column.
- **R22** (`Seq Scan on lesson_attempts`): Slow because there is no index on `started_at DESC`, forcing a full Seq Scan of 188,300 rows and sorting to discard `OFFSET 100000`.
- **R23** (`Seq Scan on daily_activity | Seq Scan on learners`): Slow because neither `(country_code, subscription)` on `learners` nor `activity_date` on `daily_activity` is indexed, scanning both tables.
- **R24** (`Seq Scan on lesson_attempts | Seq Scan on lessons | Seq Scan on units`): Slow because aggregating `hearts_lost` by `cefr_level` requires sequentially scanning and joining all 188,300 `lesson_attempts`.
- **R25** (`Seq Scan on lesson_attempts | Seq Scan on learners`): Slow because joining 188,300 `lesson_attempts` with 30,000 `learners` and grouping by `EXTRACT(HOUR FROM started_at)` scans both tables.
- **W01** (`(no scan)`): Fast single-row `INSERT` with minimal index overhead (`lesson_attempts_pkey` and two PK foreign-key checks).
- **W02** (`Index Scan using lesson_attempts_pkey on lesson_attempts`): Fast because PostgreSQL walks `lesson_attempts_pkey` backward to locate `max(attempt_id)` with `completed_at IS NULL`.
- **W03** (`(no scan)`): Fast single-row `ON CONFLICT (learner_id, activity_date)` upsert resolved directly via `daily_activity_pkey`.
- **W04** (`Seq Scan on league_memberships`): Slow because filtering `week_start = '2026-06-29'` requires a full Seq Scan of `league_memberships` before ranking cohorts.
- **W05** (`Seq Scan on achievements | Seq Scan on enrollments`): Slow because it scans all 37,500 `enrollments` rows, aggregates XP per learner, and inserts missing badges into `learner_achievements`.
