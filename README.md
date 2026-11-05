# Duolingo Language Learning Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 11 CSV files (188,300 lesson attempts): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|------|------|----------------|-----------------|
| Group Lead |Sharath Chandra Reddy Maryada |2501010264 |sharath-013 |
| Member 2 |Adem Aravind |2501010024 |AdemAravind |
| Member 3 |Sugunesh Dande |2501010462 |suguneshd |
| Member 4 |B B S V S Praveen |2501010712 |praveenbetha-24 |

**Team No.:** T0137 · **Section:** A · **Repository URL:**https://github.com/sharath-013/DE_Project_2026.git

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Duolingo teaches languages through short **lessons**. A **course** pairs the language you speak with the one you learn (e.g. English → Spanish) and is organised into **units** (with CEFR levels A1…C1) and lessons. **Learners** enroll in courses and make **lesson attempts**—finishing them earns XP; mistakes cost hearts; some attempts are abandoned. Each day's practice keeps a **streak** alive (paid learners can use streak freezes). Every week learners compete in **leagues** of about 30 and get promoted or demoted. Learners can invite friends (**referrals**) and earn **achievements**. You have joined Duolingo's data team for India.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "The **home screen** (course path, XP, daily goal, next lesson, streak counter) loads slowly." | Learner app | R01, R02, R03, R04, R06 |
| P2 | "The **leagues tab** and weekly league close take too long." | Gamification | R05, R14, W04 |
| P3 | "Starting and finishing a lesson, and updating the day's XP, must be instant." | Learner app | W01, W02, W03 |
| P4 | "The **curriculum team** needs mistake hotspots, quit rates, hearts lost and per-lesson completion reports." | Curriculum | R07, R08, R19, R24 |
| P5 | "The **referral programme** list of learners who haven't referred anyone is always **empty**." | Growth | R13 |
| P6 | "**Growth & retention** dashboards (DAU, cohort retention, streak reminders, XP trends, course popularity) time out." | Growth / Retention | R09, R15, R18, R20, R21, R25 |
| P7 | "Sign-in, friend search, achievements and the support console are slow, and activity will grow **20×**." | Platform / Monetisation | R10, R11, R12, R16, R17, R22, R23, W05 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P7, write in your own words what the business needs and which **stakeholder** is affected (learner, curriculum team, leagues/gamification team, notifications team, growth & retention, monetisation (Super/Max), support).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 11 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `languages.csv` | 10 | Languages |
| `courses.csv` | 11 | Courses (language you speak → language you learn) |
| `units.csv` | 220 | Units of each course |
| `lessons.csv` | 1,760 | Lessons inside each unit |
| `learners.csv` | 30,000 | Duolingo learners |
| `enrollments.csv` | 37,500 | Courses each learner is taking |
| `lesson_attempts.csv` | 188,300 | Every lesson attempt from 1 Jan 2025 to 30 Jun 2026 |
| `daily_activity.csv` | 189,109 | Each learner's XP per day (and streak freezes used) |
| `league_memberships.csv` | 28,598 | Weekly league placement and results |
| `achievements.csv` | 10 | Achievement badges |
| `learner_achievements.csv` | 38,860 | Badges earned by learners |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**languages.csv**
```
language_code,language_name
de,German
en,English
```

**courses.csv**
```
course_id,from_lang,learning_lang,title,launched_on
1,en,es,Spanish for English speakers,2012-11-01
2,en,fr,French for English speakers,2012-11-01
```

**units.csv**
```
unit_id,course_id,unit_no,title,cefr_level
1,1,1,Basics,A1
2,1,2,Greetings,A1
```

**lessons.csv**
```
lesson_id,unit_id,lesson_no,lesson_type,xp_value
1,1,1,LEARN,10
2,1,2,LEARN,10
```

**learners.csv**
```
learner_id,username,email,country_code,daily_goal_xp,subscription,referred_by,joined_at
1,VivaanSharma1,vivaan.sharma1@gmail.com,IN,20,FREE,,2019-01-01 00:00:00+05:30
2,Aditya_xSharma2,aditya.sharma2@gmail.com,IN,10,FREE,,2019-01-01 02:09:36+05:30
```

**enrollments.csv**
```
learner_id,course_id,enrolled_at,total_xp,is_active
1,9,2019-01-01 00:00:00+05:30,860,t
2,1,2019-01-01 02:09:36+05:30,790,t
```

**lesson_attempts.csv**
```
attempt_id,learner_id,lesson_id,started_at,completed_at,mistakes,hearts_lost,xp_earned,is_perfect,device
1,26911,1453,2025-01-01 00:00:00+05:30,,0,0,0,f,ANDROID
2,22389,727,2025-01-01 00:04:22+05:30,2025-01-01 00:11:41+05:30,0,0,25,t,ANDROID
```

**daily_activity.csv**
```
learner_id,activity_date,xp,lessons_completed,used_streak_freeze
1,2025-01-02,40,1,f
1,2025-02-02,10,1,f
```

**league_memberships.csv**
```
learner_id,week_start,tier,cohort_id,weekly_xp,final_rank,result
1,2026-04-06,GOLD,1500000,15,13,STAYED
1,2026-04-20,GOLD,1700000,15,11,STAYED
```

**achievements.csv**
```
achievement_id,code,name
1,FIRST_LESSON,First Lesson
2,STREAK_7,Week Warrior
```

**learner_achievements.csv**
```
learner_id,achievement_id,earned_at
1,1,2025-01-02 22:34:12+05:30
1,4,2019-01-31 00:00:00+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (Can a 2-letter language code be a key? Look closely at `enrollments`, `daily_activity`, `league_memberships`, `learner_achievements`, and what identifies a lesson inside a unit.)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. Why do some attempts have no `completed_at`? Why do most learners have no `referred_by`? When are `final_rank` and `result` empty?
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for formats (language codes, usernames), allowed values (CEFR levels, lesson types, tiers, results, subscriptions, daily goals), rules tying columns together (from ≠ learning language, hearts lost ≤ mistakes, a perfect lesson has no mistakes, a quit attempt earns no XP, a freeze day has 0 XP, weeks start on Monday, rank and result appear together) and self-references.
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: `enrollments.total_xp` and `daily_activity` vs `lesson_attempts`; `is_perfect` vs `mistakes`; `league_memberships.weekly_xp` vs `daily_activity`) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`duolingo`**: `CREATE SCHEMA duolingo;` and `SET search_path TO duolingo;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO duolingo;
\copy languages FROM 'seed_data/languages.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "a learner only attempts lessons of courses they are enrolled in", "`daily_activity.xp` equals that day's XP from attempts", "every league cohort has at most 30 learners"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 11 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **noticeably longer** than the others on the seed data. That's intentional. Let it finish, and don't skip it.

### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Course path: units and lessons of the Spanish course for English speakers, in order | READ | | | | |
| R02: Home screen: learner 1042's courses with total XP | READ | | | | |
| R03: Streak counter: learner 1042's current streak (consecutive days up to 30 June 2026, freezes count) | READ | | | | |
| R04: Daily goal ring: XP learner 1042 earned on 30 June 2026 vs their daily goal | READ | | | | |
| R05: Leagues tab: leaderboard of learner 1042's cohort for the week starting 29 June 2026 | READ | | | | |
| R06: "Start" button: the first lesson of learner 1042's Spanish course they have not completed yet | READ | | | | |
| R07: Curriculum team: lessons of the Spanish course with the most mistakes per attempt (100+ attempts) | READ | | | | |
| R08: Product analytics: quit rate per lesson type | READ | | | | |
| R09: Growth: daily active learners in June 2026 | READ | | | | |
| R10: Monetisation: streak freezes used per subscription tier in 2026 | READ | | | | |
| R11: Sign-in by username | READ | | | | |
| R12: Profile: learner 1042's achievements, newest first | READ | | | | |
| R13: Referral programme: learners who have not referred anyone yet | READ | | | | |
| R14: Leagues team: promotion and demotion rates per tier over the last 4 completed weeks | READ | | | | |
| R15: Retention: learners who joined in January 2026 and were still active in June 2026 | READ | | | | |
| R16: Friends: search learners by username starting with "Karan" | READ | | | | |
| R17: Product analytics: perfect-lesson rate per device in 2026 | READ | | | | |
| R18: Course popularity: enrollments per course, and how many started in 2026 | READ | | | | |
| R19: Curriculum report: completions and average mistakes of every lesson in the Spanish course | READ | | | | |
| R20: Growth: XP earned per day across the platform and running total, June 2026 | READ | | | | |
| R21: Streak reminders: learners active every day from 23 to 29 June but not yet on 30 June | READ | | | | |
| R22: Support console: all lesson attempts, newest first, page 4,001 (25 per page) | READ | | | | |
| R23: Monetisation: Super and Max learners in India who were active in the last 7 days of June 2026 | READ | | | | |
| R24: Curriculum team: average hearts lost per lesson, by CEFR level | READ | | | | |
| R25: Notifications team: lessons started per hour of the day, per country | READ | | | | |
| W01: Lesson start: learner 1042 starts lesson 1 | WRITE | | | | |
| W02: Lesson end: finish the most recent unfinished attempt of 30 June 2026 with 2 mistakes | WRITE | | | | |
| W03: Daily activity: add 20 XP to learner 1042's 1 July 2026 (creating the row if needed) | WRITE | | | | |
| W04: Weekly league close (week of 29 June 2026): rank everyone in their cohort and set promotion results | WRITE | | | | |
| W05: Achievements catch-up: award the "100 XP" badge to every learner who has 100+ XP but not the badge | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R04 | | e.g. Seq Scan on 188k attempts + DATE() | e.g. index on `lesson_attempts(learner_id, started_at)` with a sargable range | | e.g. 99% (100×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 188,300 lesson attempts. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 11 CSV files with about **20× the rows** (≈ 3,766,000 lesson attempts, ≈ 3,782,000 daily activity, ≈ 572,000 league memberships, ≈ 600,000 learners, ≈ 750,000 enrollments). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R22 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / learner-facing | R02, R03, R04, R05, R06, R11, R12, W01, W02, W03 | **under 5 ms** |
| Interactive tools | R01, R13, R16, R21, R22, R23 | **under 250 ms** |
| Reports and analytics | R07, R08, R09, R10, R14, R15, R17, R18, R19, R20, R24, R25 | **under 5,000 ms** |
| Batch jobs | W04, W05 | **under 1,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `lesson_attempts`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard by learner, by course, or by league cohort? A league leaderboard mixes 30 learners who may live on different shards. Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `lesson_attempts`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
duolingo-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Course path: units and lessons of the Spanish course for English speakers, in order**
```sql
SELECT u.unit_no, u.title, u.cefr_level, l.lesson_no, l.lesson_type, l.xp_value
FROM courses c
JOIN units u   ON u.course_id = c.course_id
JOIN lessons l ON l.unit_id = u.unit_id
WHERE c.from_lang = 'en' AND c.learning_lang = 'es'
ORDER BY u.unit_no, l.lesson_no;
```

**R02: Home screen: learner 1042's courses with total XP**
```sql
SELECT c.title, e.total_xp, e.enrolled_at, e.is_active
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
WHERE e.learner_id = 1042
ORDER BY e.total_xp DESC;
```

**R03: Streak counter: learner 1042's current streak (consecutive days up to 30 June 2026, freezes count)**
```sql
WITH days AS (
    SELECT activity_date,
           activity_date - (row_number() OVER (ORDER BY activity_date))::int AS grp
    FROM daily_activity
    WHERE learner_id = 1042 AND activity_date <= '2026-06-30'
)
SELECT count(*) AS streak_days, min(activity_date) AS streak_started
FROM days
WHERE grp = (SELECT grp FROM days WHERE activity_date = '2026-06-30');
```

**R04: Daily goal ring: XP learner 1042 earned on 30 June 2026 vs their daily goal**
```sql
SELECT l.daily_goal_xp, coalesce(sum(a.xp_earned), 0) AS xp_today
FROM learners l
LEFT JOIN lesson_attempts a ON a.learner_id = l.learner_id AND DATE(a.started_at) = '2026-06-30'
WHERE l.learner_id = 1042
GROUP BY l.daily_goal_xp;
```

**R05: Leagues tab: leaderboard of learner 1042's cohort for the week starting 29 June 2026**
```sql
SELECT lm.learner_id, le.username, lm.weekly_xp,
       RANK() OVER (ORDER BY lm.weekly_xp DESC) AS position
FROM league_memberships lm
JOIN learners le ON le.learner_id = lm.learner_id
WHERE lm.week_start = '2026-06-29'
  AND lm.cohort_id = (SELECT cohort_id FROM league_memberships WHERE learner_id = 1042 AND week_start = '2026-06-29')
ORDER BY position;
```

**R06: "Start" button: the first lesson of learner 1042's Spanish course they have not completed yet**
```sql
SELECT l.lesson_id, u.unit_no, l.lesson_no, l.lesson_type
FROM units u
JOIN lessons l ON l.unit_id = u.unit_id
WHERE u.course_id = 1
  AND NOT EXISTS (SELECT 1 FROM lesson_attempts a
                  WHERE a.learner_id = 1042 AND a.lesson_id = l.lesson_id AND a.completed_at IS NOT NULL)
ORDER BY u.unit_no, l.lesson_no
LIMIT 1;
```

**R07: Curriculum team: lessons of the Spanish course with the most mistakes per attempt (100+ attempts)**
```sql
SELECT l.lesson_id, u.unit_no, l.lesson_no, count(*) AS attempts, round(avg(a.mistakes), 2) AS avg_mistakes
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
JOIN units u   ON u.unit_id = l.unit_id
WHERE u.course_id = 1
GROUP BY l.lesson_id, u.unit_no, l.lesson_no
HAVING count(*) >= 100
ORDER BY avg_mistakes DESC
LIMIT 20;
```

**R08: Product analytics: quit rate per lesson type**
```sql
SELECT l.lesson_type, count(*) AS attempts,
       round(100.0 * count(*) FILTER (WHERE a.completed_at IS NULL) / count(*), 2) AS quit_pct
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
GROUP BY l.lesson_type
ORDER BY quit_pct DESC;
```

**R09: Growth: daily active learners in June 2026**
```sql
SELECT activity_date, count(*) AS active_learners
FROM daily_activity
WHERE xp > 0
  AND activity_date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY activity_date
ORDER BY activity_date;
```

**R10: Monetisation: streak freezes used per subscription tier in 2026**
```sql
SELECT l.subscription, count(*) AS freezes_used
FROM daily_activity d
JOIN learners l ON l.learner_id = d.learner_id
WHERE d.used_streak_freeze
  AND EXTRACT(YEAR FROM d.activity_date) = 2026
GROUP BY l.subscription
ORDER BY freezes_used DESC;
```

**R11: Sign-in by username**
```sql
SELECT learner_id, email, subscription, daily_goal_xp
FROM learners
WHERE username = 'Karan_xVerma1042';
```

**R12: Profile: learner 1042's achievements, newest first**
```sql
SELECT a.code, a.name, la.earned_at
FROM learner_achievements la
JOIN achievements a ON a.achievement_id = la.achievement_id
WHERE la.learner_id = 1042
ORDER BY la.earned_at DESC;
```

**R13: Referral programme: learners who have not referred anyone yet**
```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE l.learner_id NOT IN (SELECT r.referred_by FROM learners r);
```

**R14: Leagues team: promotion and demotion rates per tier over the last 4 completed weeks**
```sql
SELECT tier, count(*) AS memberships,
       round(100.0 * count(*) FILTER (WHERE result = 'PROMOTED') / count(*), 1) AS promoted_pct,
       round(100.0 * count(*) FILTER (WHERE result = 'DEMOTED') / count(*), 1) AS demoted_pct
FROM league_memberships
WHERE week_start BETWEEN '2026-06-01' AND '2026-06-22'
GROUP BY tier
ORDER BY tier;
```

**R15: Retention: learners who joined in January 2026 and were still active in June 2026**
```sql
SELECT count(*) AS joined_jan,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM daily_activity d WHERE d.learner_id = l.learner_id
                                      AND d.activity_date >= '2026-06-01' AND d.xp > 0)) AS active_june
FROM learners l
WHERE l.joined_at >= '2026-01-01' AND l.joined_at < '2026-02-01';
```

**R16: Friends: search learners by username starting with "Karan"**
```sql
SELECT learner_id, username, country_code
FROM learners
WHERE username ILIKE 'karan%'
ORDER BY username
LIMIT 20;
```

**R17: Product analytics: perfect-lesson rate per device in 2026**
```sql
SELECT device, count(*) AS completed,
       round(100.0 * count(*) FILTER (WHERE is_perfect) / count(*), 2) AS perfect_pct
FROM lesson_attempts
WHERE completed_at IS NOT NULL
  AND EXTRACT(YEAR FROM started_at) = 2026
GROUP BY device
ORDER BY perfect_pct DESC;
```

**R18: Course popularity: enrollments per course, and how many started in 2026**
```sql
SELECT c.title, count(*) AS learners, count(*) FILTER (WHERE e.enrolled_at >= '2026-01-01') AS new_in_2026
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
GROUP BY c.title
ORDER BY learners DESC;
```

**R19: Curriculum report: completions and average mistakes of every lesson in the Spanish course**
```sql
SELECT l.lesson_id, u.unit_no, l.lesson_no,
       (SELECT count(*) FROM lesson_attempts a WHERE a.lesson_id = l.lesson_id AND a.completed_at IS NOT NULL) AS completions,
       (SELECT round(avg(a.mistakes), 2) FROM lesson_attempts a WHERE a.lesson_id = l.lesson_id) AS avg_mistakes
FROM lessons l
JOIN units u ON u.unit_id = l.unit_id
WHERE u.course_id = 1
ORDER BY u.unit_no, l.lesson_no;
```

**R20: Growth: XP earned per day across the platform and running total, June 2026**
```sql
SELECT day, xp, sum(xp) OVER (ORDER BY day) AS running_xp
FROM (
    SELECT started_at::date AS day, sum(xp_earned) AS xp
    FROM lesson_attempts
    WHERE started_at::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day;
```

**R21: Streak reminders: learners active every day from 23 to 29 June but not yet on 30 June**
```sql
SELECT d.learner_id
FROM daily_activity d
WHERE d.activity_date BETWEEN '2026-06-23' AND '2026-06-29'
GROUP BY d.learner_id
HAVING count(*) = 7
   AND NOT EXISTS (SELECT 1 FROM daily_activity t WHERE t.learner_id = d.learner_id AND t.activity_date = '2026-06-30')
ORDER BY d.learner_id;
```

**R22: Support console: all lesson attempts, newest first, page 4,001 (25 per page)**
```sql
SELECT attempt_id, learner_id, lesson_id, started_at, xp_earned
FROM lesson_attempts
ORDER BY started_at DESC
OFFSET 100000
LIMIT 25;
```

**R23: Monetisation: Super and Max learners in India who were active in the last 7 days of June 2026**
```sql
SELECT l.subscription, count(DISTINCT l.learner_id) AS active_paid_learners
FROM learners l
JOIN daily_activity d ON d.learner_id = l.learner_id AND d.activity_date >= '2026-06-24' AND d.xp > 0
WHERE l.country_code = 'IN' AND l.subscription IN ('SUPER', 'MAX')
GROUP BY l.subscription;
```

**R24: Curriculum team: average hearts lost per lesson, by CEFR level**
```sql
SELECT u.cefr_level, count(*) AS attempts, round(avg(a.hearts_lost), 2) AS avg_hearts_lost
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
JOIN units u   ON u.unit_id = l.unit_id
GROUP BY u.cefr_level
ORDER BY u.cefr_level;
```

**R25: Notifications team: lessons started per hour of the day, per country**
```sql
SELECT le.country_code, EXTRACT(HOUR FROM a.started_at) AS hour, count(*) AS lessons
FROM lesson_attempts a
JOIN learners le ON le.learner_id = a.learner_id
GROUP BY 1, 2
ORDER BY 1, 2;
```

**W01: Lesson start: learner 1042 starts lesson 1**
```sql
INSERT INTO lesson_attempts (attempt_id, learner_id, lesson_id, started_at, device)
VALUES (90000001, 1042, 1, '2026-07-01 07:00:00+05:30', 'ANDROID');
```

**W02: Lesson end: finish the most recent unfinished attempt of 30 June 2026 with 2 mistakes**
```sql
UPDATE lesson_attempts
SET completed_at = started_at + interval '4 minutes', mistakes = 2, hearts_lost = 2, xp_earned = 10
WHERE attempt_id = (SELECT max(attempt_id) FROM lesson_attempts
                    WHERE completed_at IS NULL AND started_at >= '2026-06-30' AND started_at < '2026-07-01');
```

**W03: Daily activity: add 20 XP to learner 1042's 1 July 2026 (creating the row if needed)**
```sql
INSERT INTO daily_activity (learner_id, activity_date, xp, lessons_completed)
VALUES (1042, '2026-07-01', 20, 1)
ON CONFLICT (learner_id, activity_date)
DO UPDATE SET xp = daily_activity.xp + EXCLUDED.xp,
              lessons_completed = daily_activity.lessons_completed + EXCLUDED.lessons_completed;
```

**W04: Weekly league close (week of 29 June 2026): rank everyone in their cohort and set promotion results**
```sql
UPDATE league_memberships lm
SET final_rank = r.rnk,
    result = CASE WHEN r.rnk <= 7 THEN 'PROMOTED' WHEN r.rnk >= 26 THEN 'DEMOTED' ELSE 'STAYED' END
FROM (SELECT learner_id, week_start,
             row_number() OVER (PARTITION BY cohort_id ORDER BY weekly_xp DESC, learner_id) AS rnk
      FROM league_memberships WHERE week_start = '2026-06-29') r
WHERE lm.learner_id = r.learner_id AND lm.week_start = r.week_start;
```

**W05: Achievements catch-up: award the "100 XP" badge to every learner who has 100+ XP but not the badge**
```sql
INSERT INTO learner_achievements (learner_id, achievement_id, earned_at)
SELECT e.learner_id, (SELECT achievement_id FROM achievements WHERE code = 'XP_100'), '2026-07-01 00:00:00+05:30'
FROM enrollments e
GROUP BY e.learner_id
HAVING sum(e.total_xp) >= 100
ON CONFLICT (learner_id, achievement_id) DO NOTHING;
```
