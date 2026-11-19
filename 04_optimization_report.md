# Phase 4: Optimization Report

Team T0137 · We made the 30 queries faster without changing their results. The only exception is R13, which gave a **wrong answer**, so we fixed it on purpose (see section 4).

## 1. What we did
1. We read the baseline plans (`benchmarks/results/baseline/`) and found why each slow query was slow.
2. We added **9 indexes** (`sql/05_indexes.sql`). Every index has a comment on which queries it helps and why.
3. We rewrote **8 queries** (`sql/06_optimized_queries.sql`): R04, R10, R13, R16, R17, R19, R20, R23. The other 22 are unchanged.
4. We proved the results are the same (`sql/07_verify_results.sql`, section 5).
5. We ran the benchmark again with the same method and the same laptop.

The techniques we used (from the README list): composite B-tree index, covering index (`INCLUDE`), partial index, expression index, query rewrite (sargable date ranges, `NOT EXISTS`, join instead of correlated subqueries), and `VACUUM` / `ANALYZE`.

## 2. How we measured
| Item | Value |
|---|---|
| PostgreSQL version | TODO |
| Laptop (same as Phase 3) | TODO |
| Data | seed data, 188,300 lesson attempts |
| Method | `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs, average. Writes inside `BEGIN; ... ROLLBACK;` |

Commands we used:
```bash
psql -d <our_database> -f sql/05_indexes.sql        # creates the indexes, then VACUUM (ANALYZE)
./benchmarks/run_benchmark.sh <our_database> optimized 5 sql/06_optimized_queries.sql
```
Results are in `benchmarks/results/optimized/`. **Every number below is copied from the raw plan files** of `baseline/` and `optimized/`.

## 3. Optimization table
Improvement % = (before − after) / before × 100.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | | TODO | None. Query unchanged (small tables) | | | Yes (not changed) |
| R02 | | TODO | None. Query unchanged (uses the primary key) | | | Yes (not changed) |
| R03 | | TODO | None. Query unchanged (uses the primary key) | | | Yes (not changed) |
| R04 | | TODO | Rewrite `DATE(started_at) = day` as a date range, plus `idx_attempts_learner_started` | | | TODO |
| R05 | | TODO | `idx_league_week_cohort`. Query unchanged | | | Yes (not changed) |
| R06 | | TODO | `idx_attempts_learner_started`. Query unchanged | | | Yes (not changed) |
| R07 | | TODO | `idx_attempts_lesson`. Query unchanged | | | Yes (not changed) |
| R08 | | TODO | `idx_attempts_lesson` (covering index). Query unchanged | | | Yes (not changed) |
| R09 | | TODO | `idx_daily_date_cover`. Query unchanged | | | Yes (not changed) |
| R10 | | TODO | Rewrite `EXTRACT(YEAR ...)` as a date range, plus partial index `idx_daily_freeze` | | | TODO |
| R11 | | TODO | None. Query unchanged (UNIQUE index on `username`) | | | Yes (not changed) |
| R12 | | TODO | None. Query unchanged (uses the primary key) | | | Yes (not changed) |
| R13 | | TODO | Rewrite `NOT IN` as `NOT EXISTS` (fixes the wrong result), plus partial index `idx_learners_referred_by` | | | No, fixed on purpose (section 4) |
| R14 | | TODO | `idx_league_week_cohort`. Query unchanged | | | Yes (not changed) |
| R15 | | TODO | `idx_learners_joined_at`. Query unchanged | | | Yes (not changed) |
| R16 | | TODO | Rewrite `ILIKE` as `lower(username) LIKE`, plus expression index `idx_learners_username_lower` | | | TODO |
| R17 | | TODO | Rewrite `EXTRACT(YEAR ...)` as a timestamp range (no new index) | | | TODO |
| R18 | | TODO | None. Query unchanged (it has to read all enrollments) | | | Yes (not changed) |
| R19 | | TODO | Rewrite two subqueries per lesson as one join with a group, plus `idx_attempts_lesson` | | | TODO |
| R20 | | TODO | Rewrite `started_at::date` as a timestamp range, plus `idx_attempts_started_desc` | | | TODO |
| R21 | | TODO | `idx_daily_date_cover`. Query unchanged | | | Yes (not changed) |
| R22 | | TODO | `idx_attempts_started_desc` (same order as the query). Query unchanged | | | Yes (not changed) |
| R23 | | TODO | Rewrite `count(DISTINCT)` over a join as `EXISTS`, plus `idx_daily_date_cover` | | | TODO |
| R24 | | TODO | `idx_attempts_lesson` (covering index). Query unchanged | | | Yes (not changed) |
| R25 | | TODO | None. Query unchanged (it has to read all attempts) | | | Yes (not changed) |
| W01 | | TODO | None. Query unchanged (but it must update the new indexes) | | | Yes (not changed) |
| W02 | | TODO | None. Query unchanged (but it must update the new indexes) | | | Yes (not changed) |
| W03 | | TODO | None. Query unchanged (but it must update the new index) | | | Yes (not changed) |
| W04 | | TODO | `idx_league_week_cohort`. Query unchanged | | | Yes (not changed) |
| W05 | | TODO | None. Query unchanged (it has to read all enrollments) | | | Yes (not changed) |
| **Total** | | | | | | |

For "Problem found in the plan" we write what the baseline plan really showed, for example "Seq Scan on lesson_attempts, 188,300 rows read" and the `Execution Time`. The hints in `docs/03_baseline_timings.md`, section 3, can help, but we only write what we saw.

## 4. The wrong-result query: R13
**What the business wanted:** the list of learners who have not referred anyone yet (problem P5).

**Old query:**
```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE l.learner_id NOT IN (SELECT r.referred_by FROM learners r);
```
**What went wrong:** most learners have `referred_by = NULL`, so the list inside `NOT IN` contains NULL. In SQL, `x NOT IN (1, 2, NULL)` can never be TRUE: for any x that is not 1 or 2 it is UNKNOWN. So the query returns **0 rows for everybody**. It is not slow, it is just wrong.

**New query:**
```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE NOT EXISTS (SELECT 1 FROM learners r WHERE r.referred_by = l.learner_id);
```
`NOT EXISTS` only asks "is there a learner who was referred by this learner?", so NULL values do not matter.

**Proof** (output of the R13 part of `sql/07_verify_results.sql`):

| rows_old_query | rows_new_query | rows_expected |
|---:|---:|---:|
| TODO (should be 0) | TODO | TODO (should be equal to rows_new_query) |

`rows_expected` is a third way to count: all learners minus the learners who are a referrer. The new query must match it.

## 5. Proof that the results are unchanged
We ran `psql -d <our_database> -f sql/07_verify_results.sql`. For every rewritten query it runs the old and the new version side by side and compares them (EXCEPT in both directions). We expect equal row counts and 0 rows in both "only_in" columns.

| Query | rows_original | rows_optimized | only_in_original | only_in_optimized | Same? |
|---|---:|---:|---:|---:|:---:|
| R04 | TODO | TODO | TODO | TODO | TODO |
| R10 | TODO | TODO | TODO | TODO | TODO |
| R16 | TODO | TODO | TODO | TODO | TODO |
| R17 | TODO | TODO | TODO | TODO | TODO |
| R19 | TODO | TODO | TODO | TODO | TODO |
| R20 | TODO | TODO | TODO | TODO | TODO |
| R23 | TODO | TODO | TODO | TODO | TODO |

The ORDER BY of every query was not changed. The 22 unchanged queries cannot change their result, because an index only changes how rows are found, not which rows exist.

## 6. Before and after plans of our 5 biggest improvements
`TODO: after measuring, pick the 5 queries with the biggest improvement. For each one, paste the "Execution Time" and the main plan lines from baseline/<query>.txt and optimized/<query>.txt, and say in 2 lines what changed (for example "Seq Scan became Index Only Scan").`

### Query TODO
Before:
```
TODO
```
After:
```
TODO
```

(Repeat this block for each of the 5 queries.)

## 7. Write overhead
Every index must be updated when we insert or update a row, so writes can become slower. The table shows the write queries.

| Query | Before (ms) | After (ms) | Change | Acceptable? |
|---|---:|---:|---:|---|
| W01 | | | | TODO |
| W02 | | | | TODO |
| W03 | | | | TODO |
| W04 | | | | TODO |
| W05 | | | | TODO |

**Why we expect some writes to be slower:** W01 adds a row to `lesson_attempts`, so it must add an entry to 3 new indexes. W02 changes `completed_at`, `mistakes`, `hearts_lost` and `xp_earned`, which are stored inside the covering indexes, so PostgreSQL cannot do a HOT update and must update them too. W03 changes `xp`, which is inside `idx_daily_date_cover`. We kept `final_rank` and `result` out of `idx_league_week_cohort` so W04 does not pay this cost.

`TODO: write for each query, using the numbers above, if the change is acceptable and why. Think about how often the app really runs it (a lesson ends many times per second, but W04 runs once a week).`

## 8. Index storage
We ran the last query of `sql/05_indexes.sql` (it uses `pg_relation_size`).

| Table | Index | Index size | Table size |
|---|---|---:|---:|
| TODO | TODO | TODO | TODO |

`TODO: add one or two lines. For example, which index is the biggest, and whether the total size of the indexes is acceptable next to the size of the tables.`

## 9. Queries we could not speed up much
`TODO: write after measuring, with the numbers.` Candidates (check them in the plans before writing):
- **R08, R24, R25** have to read every lesson attempt, so they cannot avoid reading about the whole table.
- **R18** has to read every enrollment.
- **W05** has to group all enrollments.
- **R01, R02, R03, R11, R12** were probably already fast. If so, we say so.

## 10. Notes for Phase 5
`TODO: after measuring, write what could become slow on 20 times more data, for example queries that read a fixed share of the table, and R22 with a big OFFSET.`
