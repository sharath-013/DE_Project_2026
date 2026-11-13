# Phase 2: Schema Design

Team T0137 · Schema name: `duolingo`
Files for this phase: `sql/01_schema.sql`, `sql/02_load_data.sql`, `sql/03_integrity_checks.sql`

## 1. Our approach
The README did not give us any `CREATE TABLE` statements, only 11 CSV files. So we opened every file, read the headers and the first rows, and worked out the tables ourselves.

The main thing we noticed is that course content is like a tree:

**language → course → unit → lesson**

Learners then connect to this tree. A learner enrolls in courses, makes lesson attempts, gets one activity row per day, one league row per week, and earns badges. Every table has a primary key, and every link between tables is a foreign key.

We kept the table names and column names exactly the same as the CSV files, because the 30 queries use them.

## 2. ER diagram
![ER diagram](../diagrams/er_diagram.png)

The Mermaid code is in `diagrams/er_diagram.mmd`.

| Relationship | Type | In simple words |
|---|---|---|
| languages → courses | 1:N (two links) | One language can be the "speaks" side and the "learns" side of many courses |
| courses → units | 1:N | One course has many units |
| units → lessons | 1:N | One unit has many lessons |
| learners → learners | 1:N (self link) | One learner can refer many friends, but each learner has only one referrer |
| learners ↔ courses | M:N, using `enrollments` | A learner takes many courses, and a course has many learners |
| learners → lesson_attempts | 1:N | One learner makes many attempts |
| lessons → lesson_attempts | 1:N | One lesson is attempted many times |
| learners → daily_activity | 1:N | One row for each day the learner practised |
| learners → league_memberships | 1:N | One row for each week the learner was in a league |
| learners ↔ achievements | M:N, using `learner_achievements` | A learner earns many badges, and a badge is earned by many learners |

## 3. Data dictionary
**How we chose data types:** we used the smallest type that is safe. `SMALLINT` for small numbers, `INTEGER` for ids that can grow big, `BIGINT` only for `attempt_id` (the biggest table), `CHAR(2)` for fixed 2-letter codes, `BOOLEAN` for the t/f columns, `DATE` when time is not needed, and `TIMESTAMPTZ` for times because the data has an offset like `+05:30`.

### 3.1 languages (10 rows) · PK: language_code
| Column | Type | Constraint | Why |
|---|---|---|---|
| language_code | CHAR(2) | PK, CHECK 2 small letters | Always 2 letters and never changes, so it is a good key |
| language_name | VARCHAR(50) | NOT NULL, UNIQUE | Two languages cannot have the same name |

### 3.2 courses (11 rows) · PK: course_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| course_id | SMALLINT | PK | Only 11 courses |
| from_lang | CHAR(2) | NOT NULL, FK → languages, ON DELETE RESTRICT | The language the learner speaks |
| learning_lang | CHAR(2) | NOT NULL, FK → languages, ON DELETE RESTRICT | The language the learner learns |
| title | VARCHAR(100) | NOT NULL | Name shown in the app |
| launched_on | DATE | NOT NULL | Only the date matters |

Other rules: `UNIQUE (from_lang, learning_lang)` so there is one course per pair, and `CHECK (from_lang <> learning_lang)` because nobody learns the language they already speak.
We used RESTRICT so a language cannot be deleted while a course still uses it.

### 3.3 units (220 rows) · PK: unit_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| unit_id | INTEGER | PK | |
| course_id | SMALLINT | NOT NULL, FK → courses, ON DELETE CASCADE | A unit makes no sense without its course |
| unit_no | SMALLINT | NOT NULL, CHECK > 0 | Position of the unit in the course |
| title | VARCHAR(100) | NOT NULL | |
| cefr_level | VARCHAR(2) | NOT NULL, CHECK in (A1, A2, B1, B2, C1, C2) | CEFR language levels |

Other rule: `UNIQUE (course_id, unit_no)` so two units in a course cannot have the same number.

### 3.4 lessons (1,760 rows) · PK: lesson_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| lesson_id | INTEGER | PK | |
| unit_id | INTEGER | NOT NULL, FK → units, ON DELETE CASCADE | A lesson belongs to one unit |
| lesson_no | SMALLINT | NOT NULL, CHECK > 0 | Position of the lesson in the unit |
| lesson_type | VARCHAR(15) | NOT NULL, CHECK in allowed list | Only a fixed set of types exists |
| xp_value | SMALLINT | NOT NULL, CHECK > 0 | Every lesson gives some XP |

Other rule: `UNIQUE (unit_id, lesson_no)`. This is how a lesson is identified inside a unit.

### 3.5 learners (30,000 rows) · PK: learner_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| learner_id | INTEGER | PK | |
| username | VARCHAR(30) | NOT NULL, UNIQUE, CHECK letters/digits/underscore | Used to sign in (R11), so it must be unique |
| email | VARCHAR(100) | NOT NULL, UNIQUE, CHECK looks like an email | Another unique value for a learner |
| country_code | CHAR(2) | NOT NULL, CHECK 2 capital letters | Fixed 2-letter code |
| daily_goal_xp | SMALLINT | NOT NULL, DEFAULT 10, CHECK in allowed list | The goals come in fixed steps |
| subscription | VARCHAR(5) | NOT NULL, DEFAULT 'FREE', CHECK in (FREE, SUPER, MAX) | Three plans only |
| referred_by | INTEGER | **NULL allowed**, FK → learners, ON DELETE SET NULL, CHECK not own id | See below |
| joined_at | TIMESTAMPTZ | NOT NULL | Has a time zone offset |

`referred_by` is empty for learners who joined without a referral, so it must allow NULL. It points to the same table (self reference). If the referrer is deleted we use SET NULL so the referred learner is not deleted with them. The CHECK stops a learner from referring themselves.

### 3.6 enrollments (37,500 rows) · PK: (learner_id, course_id)
| Column | Type | Constraint | Why |
|---|---|---|---|
| learner_id | INTEGER | FK → learners, ON DELETE CASCADE | If the learner is deleted, their enrollments go too |
| course_id | SMALLINT | FK → courses, ON DELETE RESTRICT | We do not want to delete a course that has learners |
| enrolled_at | TIMESTAMPTZ | NOT NULL | |
| total_xp | INTEGER | NOT NULL, DEFAULT 0, CHECK >= 0 | XP can never be negative |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | |

The key is two columns together because a learner can enroll in a course only once, and one learner can be in many courses.

### 3.7 lesson_attempts (188,300 rows) · PK: attempt_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| attempt_id | BIGINT | PK | This table grows the most, so we used BIGINT |
| learner_id | INTEGER | NOT NULL, FK → learners, ON DELETE CASCADE | |
| lesson_id | INTEGER | NOT NULL, FK → lessons, ON DELETE RESTRICT | We keep the history, so a lesson with attempts cannot be deleted |
| started_at | TIMESTAMPTZ | NOT NULL | Every attempt has a start time |
| completed_at | TIMESTAMPTZ | **NULL allowed**, CHECK >= started_at | NULL means the learner quit or has not finished yet |
| mistakes | SMALLINT | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| hearts_lost | SMALLINT | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| xp_earned | SMALLINT | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| is_perfect | BOOLEAN | NOT NULL, DEFAULT FALSE | |
| device | VARCHAR(10) | NOT NULL, CHECK in allowed list | |

The DEFAULT values are needed because query W01 inserts a new attempt without giving mistakes, hearts_lost, xp_earned or is_perfect.

Business rules written as CHECKs:
- hearts_lost cannot be more than mistakes
- a perfect lesson has 0 mistakes
- a quit attempt (completed_at is NULL) earns 0 XP

### 3.8 daily_activity (189,109 rows) · PK: (learner_id, activity_date)
| Column | Type | Constraint | Why |
|---|---|---|---|
| learner_id | INTEGER | FK → learners, ON DELETE CASCADE | |
| activity_date | DATE | NOT NULL | Only the day is needed |
| xp | INTEGER | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| lessons_completed | SMALLINT | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| used_streak_freeze | BOOLEAN | NOT NULL, DEFAULT FALSE | |

The key is (learner_id, activity_date) because there is one row per learner per day. Query W03 uses `ON CONFLICT (learner_id, activity_date)`, so this key is required.
CHECK: if a streak freeze was used, xp must be 0.

### 3.9 league_memberships (28,598 rows) · PK: (learner_id, week_start)
| Column | Type | Constraint | Why |
|---|---|---|---|
| learner_id | INTEGER | FK → learners, ON DELETE CASCADE | |
| week_start | DATE | NOT NULL, CHECK it is a Monday | Leagues start on Monday |
| tier | VARCHAR(12) | NOT NULL, CHECK capital letters only | League name like GOLD |
| cohort_id | INTEGER | NOT NULL | The group of about 30 learners |
| weekly_xp | INTEGER | NOT NULL, DEFAULT 0, CHECK >= 0 | |
| final_rank | SMALLINT | **NULL allowed**, CHECK between 1 and 30 | Empty until the week is closed |
| result | VARCHAR(8) | **NULL allowed**, CHECK in (PROMOTED, STAYED, DEMOTED) | Empty until the week is closed |

`final_rank` and `result` are filled by query W04 when the week ends, so they are NULL before that. We added a CHECK that both are NULL together or both are filled together.

### 3.10 achievements (10 rows) · PK: achievement_id
| Column | Type | Constraint | Why |
|---|---|---|---|
| achievement_id | SMALLINT | PK | |
| code | VARCHAR(30) | NOT NULL, UNIQUE, CHECK capital letters/digits/underscore | W05 finds the badge using its code |
| name | VARCHAR(60) | NOT NULL, UNIQUE | |

### 3.11 learner_achievements (38,860 rows) · PK: (learner_id, achievement_id)
| Column | Type | Constraint | Why |
|---|---|---|---|
| learner_id | INTEGER | FK → learners, ON DELETE CASCADE | |
| achievement_id | SMALLINT | FK → achievements, ON DELETE RESTRICT | Do not delete a badge that learners have earned |
| earned_at | TIMESTAMPTZ | NOT NULL | |

This is the table that breaks the many-to-many link. A learner can earn each badge only once, and W05 depends on that with `ON CONFLICT DO NOTHING`.

## 4. Functional dependencies and normal form
In every table, each non-key column depends on the whole key and nothing else. The only other determinants are UNIQUE columns, which are also keys. So all 11 tables are in **3NF and BCNF**.

| Table | Functional dependencies | Normal form |
|---|---|---|
| languages | language_code → language_name, and language_name → language_code | BCNF |
| courses | course_id → all columns; (from_lang, learning_lang) → course_id | BCNF |
| units | unit_id → all columns; (course_id, unit_no) → unit_id | BCNF |
| lessons | lesson_id → all columns; (unit_id, lesson_no) → lesson_id | BCNF |
| learners | learner_id → all columns; username → learner_id; email → learner_id | BCNF |
| enrollments | (learner_id, course_id) → enrolled_at, total_xp, is_active | BCNF |
| lesson_attempts | attempt_id → all columns | BCNF |
| daily_activity | (learner_id, activity_date) → xp, lessons_completed, used_streak_freeze | BCNF |
| league_memberships | (learner_id, week_start) → tier, cohort_id, weekly_xp, final_rank, result | BCNF |
| achievements | achievement_id → all columns; code → achievement_id; name → achievement_id | BCNF |
| learner_achievements | (learner_id, achievement_id) → earned_at | BCNF |

Example of why it is clean: `cefr_level` is stored in `units` and not in `lessons`, because the level depends on the unit and not on the lesson. So there is no transitive dependency.

## 5. Derived (repeated) columns: do we keep them?
Some columns can be calculated from other tables. Storing them breaks pure normalization, but we decided to keep all four because they make the important queries fast.

| Column | Can be calculated from | Keep? | Reason |
|---|---|---|---|
| enrollments.total_xp | Sum of `lesson_attempts.xp_earned` for that learner and course | Yes | The home screen (R02) and W05 read it directly. Without it we would scan all attempts every time. The cost is that it must be updated after every lesson |
| daily_activity.xp | Sum of `xp_earned` for that learner and day | Yes | The streak, daily active users and retention queries (R03, R09, R15, R21) read one small row per day instead of many attempts |
| lesson_attempts.is_perfect | completed and `mistakes = 0` | Yes | Saves a calculation in R17. The CHECK makes sure a perfect attempt never has mistakes. It is not fully derived because a quit attempt also has 0 mistakes but is not perfect |
| league_memberships.weekly_xp | Sum of `daily_activity.xp` for that week | Yes | The leaderboard (R05) sorts by this value and must be fast |

In section 7 we check if these stored values really match the source data.

## 6. Checking the allowed values before loading
Some CHECK lists (the lines marked `VERIFY` in `01_schema.sql`) are based on our reading of the first rows. Before loading we run these commands inside the folder that has `seed_data/`, to see every real value:

```bash
cut -d, -f4 seed_data/lessons.csv | tail -n +2 | sort | uniq -c            # lesson_type
cut -d, -f10 seed_data/lesson_attempts.csv | tail -n +2 | sort | uniq -c   # device
cut -d, -f3 seed_data/league_memberships.csv | tail -n +2 | sort | uniq -c # tier
cut -d, -f5 seed_data/learners.csv | tail -n +2 | sort | uniq -c           # daily_goal_xp
cut -d, -f6 seed_data/learners.csv | tail -n +2 | sort | uniq -c           # subscription
cut -d, -f5 seed_data/units.csv | tail -n +2 | sort | uniq -c              # cefr_level
```

If a list is different from our CHECK, we change the CHECK in `01_schema.sql`.

**Values found:** `TODO: write the values found for each column`

## 7. Loading the data and integrity checks
Steps we run, in this order:
1. `psql -d <db> -f sql/01_schema.sql`
2. `psql -d <db> -f sql/02_load_data.sql` (parents are loaded before children so the foreign keys work)
3. `psql -d <db> -f sql/03_integrity_checks.sql`

**Row counts after loading (must match the README):** `TODO: paste the output of 02_load_data.sql`

| Check | What it proves | Result |
|---|---|---|
| C1 | Learners only attempt lessons from courses they enrolled in | TODO |
| C2 | `daily_activity.xp` is equal to the XP from attempts on that day | TODO |
| C3 | No league cohort has more than 30 learners | TODO |
| C4 | `weekly_xp` is equal to the sum of daily XP in that week | TODO |
| C5 | `enrollments.total_xp` is equal to the XP from attempts | TODO |
| C6 | How many learners have `referred_by` as NULL | TODO |
| C7 | Quit attempts that earned XP (should be 0) | TODO |
| C8 | Closed weeks that have no result (should be 0) | TODO |

For C1 to C5 and C7 and C8 we expect 0 bad rows. C6 is only information.

## 8. Data problems we found
Only the problems that the load and the checks really showed should be written here.

**Point we already know about:** most learners have `referred_by = NULL`. This is correct data, not an error. But it matters for Phase 4: query R13 uses `NOT IN (SELECT referred_by ...)`, and when that list contains even one NULL, `NOT IN` returns no rows. This is why the referral team sees an empty result (problem P5).

`TODO: add any other problem found, for example a check from C1 to C5 that is not 0, or a constraint that rejected rows during the load. For each one say how many rows, and whether our constraint was wrong or the data was wrong.`

## 9. Indexes that exist after Phase 2
We created only constraints in this phase and no extra indexes, so that the Phase 3 baseline is fair. PostgreSQL automatically creates an index for every PRIMARY KEY and UNIQUE constraint, so these are the only ones:

| Table | Automatic indexes |
|---|---|
| languages | PK (language_code), UNIQUE (language_name) |
| courses | PK (course_id), UNIQUE (from_lang, learning_lang) |
| units | PK (unit_id), UNIQUE (course_id, unit_no) |
| lessons | PK (lesson_id), UNIQUE (unit_id, lesson_no) |
| learners | PK (learner_id), UNIQUE (username), UNIQUE (email) |
| enrollments | PK (learner_id, course_id) |
| lesson_attempts | PK (attempt_id) only |
| daily_activity | PK (learner_id, activity_date) |
| league_memberships | PK (learner_id, week_start) |
| achievements | PK (achievement_id), UNIQUE (code), UNIQUE (name) |
| learner_achievements | PK (learner_id, achievement_id) |

Notice that `lesson_attempts` has no index on `learner_id` or `started_at`. Many queries filter on these, so we expect them to be slow in Phase 3.
