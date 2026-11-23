# Phase 5: Scalability Report

Team T0137 · Next year the business expects **20 times** more data. In this report we test our optimized database on the large dataset and we design what we would do for **100 times** more data.

| | Seed data | Large data |
|---|---:|---:|
| Lesson attempts | 188,300 | TODO (about 3,766,000) |
| Daily activity | 189,109 | TODO (about 3,782,000) |
| League memberships | 28,598 | TODO (about 572,000) |
| Learners | 30,000 | TODO (about 600,000) |
| Enrollments | 37,500 | TODO (about 750,000) |

## 1. How we ran the large test
1. We created a new database and ran `sql/01_schema.sql`.
2. We loaded `large_data/` with `sql/02_load_data.sql` (we only changed the folder name).
3. We ran `sql/05_indexes.sql` (this also runs `VACUUM (ANALYZE)`).
4. We ran only our **optimized** queries, `sql/06_optimized_queries.sql`. We did **not** run the original 30 on the large data.
5. We set the time zone of the session to `Asia/Kolkata`, like the data.

| Item | Value |
|---|---|
| PostgreSQL version | TODO |
| Laptop (same as Phase 3 and 4) | TODO |
| Method | `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs, average. Writes inside `BEGIN; ... ROLLBACK;` |

Command (check the first lines of `benchmarks/run_benchmark.sh` for the exact arguments):
```bash
./benchmarks/run_benchmark.sh <large_database> large 3 sql/06_optimized_queries.sql
```
Results are in `benchmarks/results/large/`. **Every number below is copied from the plan files** in `optimized/` and `large/`.

## 2. Performance targets
| Query group | Queries | Target (average of 3 runs) |
|---|---|---:|
| Real-time / learner-facing | R02, R03, R04, R05, R06, R11, R12, W01, W02, W03 | under 5 ms |
| Interactive tools | R01, R13, R16, R21, R22, R23 | under 250 ms |
| Reports and analytics | R07, R08, R09, R10, R14, R15, R17, R18, R19, R20, R24, R25 | under 5,000 ms |
| Batch jobs | W04, W05 | under 1,000 ms |

## 3. Results on the large dataset
Growth = large ÷ seed. "Meets target?" compares the large time with the target of its group in section 2.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what we changed |
|---|---:|---:|---:|:---:|---|
| R01 | | | | | |
| R02 | | | | | |
| R03 | | | | | |
| R04 | | | | | |
| R05 | | | | | |
| R06 | | | | | |
| R07 | | | | | |
| R08 | | | | | |
| R09 | | | | | |
| R10 | | | | | |
| R11 | | | | | |
| R12 | | | | | |
| R13 | | | | | |
| R14 | | | | | |
| R15 | | | | | |
| R16 | | | | | |
| R17 | | | | | |
| R18 | | | | | |
| R19 | | | | | |
| R20 | | | | | |
| R21 | | | | | |
| R22 | | | | | |
| R23 | | | | | |
| R24 | | | | | |
| R25 | | | | | |
| W01 | | | | | |
| W02 | | | | | |
| W03 | | | | | |
| W04 | | | | | |
| W05 | | | | | |

`TODO: for every query that misses its target, write what we changed, with a link to the before and after plan (section 5).`

**R22 (page 4,001 with OFFSET):** we kept `OFFSET 100000` in the optimized query, so it skips exactly 100,000 rows on any data size. We did not use keyset pagination, so there is no "last seen" value to choose. `TODO: say if this still meets the 250 ms target on the large data and why.`

## 4. Growth analysis
We group the queries by how their time grew when the data grew about 20 times.
`TODO: fill each group with the real queries and growth numbers from section 3.`

**Stayed about the same (growth below about 3 times)**
- Queries: TODO
- Why: they find rows with an index on one learner or one key, and an index lookup grows only with log(n), not with n. Our hypothesis: R02, R03, R11 and R12. R22 may also stay the same, because the OFFSET is always 100,000. We check this against the numbers.

**Grew about 20 times (growth roughly between 3 and 40 times)**
- Queries: TODO
- Why: they read a fixed share of the table, so 20 times more rows means about 20 times more work. Our hypothesis: R08, R18, R24, R25 (they read every row), R07 and R19 (they read all attempts of the Spanish course), and W05 (it groups all enrollments).

**Grew more than 20 times (growth above about 40 times)**
- Queries: TODO (maybe none)
- Why and what we did: TODO. A typical reason is that the data no longer fits in memory, or a sort or hash spills to disk.

## 5. What broke at scale and how we fixed it
`TODO: write one block for each problem that only appeared on the large data.` What to look for in the large plans:

| Sign in the plan | What it means | A possible fix |
|---|---|---|
| `Sort Method: external merge  Disk: ...` | The sort did not fit in `work_mem` and went to disk | Make the sort smaller (filter first, fewer columns), or change the query. We do not change server settings to hide a problem |
| `Batches: 2` or more on a Hash node | The hash table went to disk | Same as above |
| `Heap Fetches: N` is big on an Index Only Scan | The visibility map is old | Run `VACUUM` after loading |
| `Seq Scan` where we expected an index | Old statistics, or the index is not selective enough | Run `ANALYZE`, check the filter, check the column order of the index |
| `Rows Removed by Filter` is huge | An index is missing or has the wrong column order | Change the index |

### Problem 1: TODO
Before:
```
TODO
```
After:
```
TODO
```

(Repeat for every problem. If nothing broke, we write that and show the plans of the three slowest queries as proof.)

## 6. Storage
Commands we ran on both databases (seed and large):
```sql
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;

SELECT c.relname AS table_name,
       pg_size_pretty(pg_table_size(c.oid))          AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid))        AS index_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'duolingo' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;
```

| | Seed data | Large data | Growth |
|---|---:|---:|---:|
| Total database size | TODO | TODO | TODO |
| `lesson_attempts`: table / indexes | TODO / TODO | TODO / TODO | TODO |
| `daily_activity`: table / indexes | TODO / TODO | TODO / TODO | TODO |
| All tables / all indexes | TODO / TODO | TODO / TODO | TODO |

`TODO: write 2 lines: do the indexes grow in the same way as the tables, and what is the size of the indexes compared with the tables?`

## 7. Architecture for 100 times more data
At 100 times the seed data, `lesson_attempts` would have about 18.8 million rows and `daily_activity` about 18.9 million rows (100 × 188,300 and 100 × 189,109). We use our own measurements as the base: `TODO: our measured size and query time of the biggest table on the large data, and what that means at 5 times the large data.`

### 7.1 Partitioning
- **Table:** `lesson_attempts`, because it is the biggest and grows fastest.
- **Type and column:** RANGE on `started_at`, one partition for each month.
- **Why RANGE on `started_at`:**
  1. Many queries filter by date (R04 one day, R17 one year, R20 one month, R22 newest first). PostgreSQL then reads only the months it needs (partition pruning).
  2. New rows always go to the newest partition and old months never change, so VACUUM has no work on them.
  3. We can archive a month very fast with `DETACH PARTITION` and `DROP`, instead of a slow `DELETE` of millions of rows.
- **Why not HASH or LIST:** HASH on `learner_id` helps learner queries, but then every date query must read all partitions. LIST needs a small fixed list of values, and we have none.
- **DDL:** `sql/08_partitioning.sql` creates `lesson_attempts_p` with monthly partitions from 2025-01 to 2026-12, a DEFAULT partition, the same CHECK constraints and the same 3 indexes.
- **Primary key rule:** a PRIMARY KEY or UNIQUE constraint on a partitioned table must contain the partition column. So `attempt_id` alone is not allowed, and the key becomes `(attempt_id, started_at)`. PostgreSQL then cannot promise that `attempt_id` is unique alone, so the app must take the ids from one sequence. No other table has a foreign key to `lesson_attempts`, so nothing breaks.
- **Time zone:** the month limits are written with `+05:30`. The session time zone must also be `Asia/Kolkata`. We tested a one-day filter in a UTC session and it read two partitions instead of one, because the month limits are in India time.
- **Maintenance:** create next year's partitions before the year starts. If a row has no partition it goes to the DEFAULT partition, which should stay empty.

**Pruning with EXPLAIN** (output of the last part of `sql/08_partitioning.sql` on the large data):

| Filter | Partitions read (expected) | Partitions read (we saw) |
|---|---:|---:|
| One day (like R04) | 1 | TODO |
| One month (like R20) | 1 | TODO |
| One year (like R17) | 12 | TODO |
| No date filter (like R08) | all | TODO |
| `DATE(started_at) = day` (the old way) | all | TODO |

```
TODO: paste the EXPLAIN (COSTS OFF) of the one-month query here.
```
Partitioning does not make every query faster: queries without a date filter still read all partitions. `TODO: our own timing of R20 or R04 on lesson_attempts and lesson_attempts_p, if we measured it.`

`daily_activity` (by `activity_date`) and `league_memberships` (by `week_start`) could be partitioned in the same way. We do not need this for 20 times more data.

### 7.2 Sharding
**We would shard by `learner_id`** (hash of the id). The real-time queries (R02 to R06, R11, R12, W01 to W03) all work on one learner, so one learner's rows (enrollments, attempts, daily activity, achievements) stay on one shard and these queries touch only one shard. The small reference tables (languages, courses, units, lessons, achievements) are copied to every shard.

Why not by course or by cohort: a learner is in many courses and the home screen needs all of them, so sharding by course would split the learner's data. Sharding by cohort would put all the data of a learner in a different place every week.

**Queries that become cross-shard, and what we would do:**

| Query | Why it crosses shards | How we would handle it |
|---|---|---|
| R05 leaderboard, W04 league close | The 30 learners of a cohort live on different shards | Keep `league_memberships` in its own store sharded by `cohort_id`. The learner shards send the XP of the week to it (a few seconds late is fine) and it keeps the username |
| R11 sign-in by username | We do not know the shard from a username | A small username to learner_id directory table, copied to every node |
| R13 referrals | `referred_by` points to a learner on another shard | A `referrals` table sharded by the referrer, or run it as a report on the analytics copy |
| R09, R10, R14, R15, R17, R18, R20, R21, R23, R25 and other reports | They read all learners | Run on each shard (scatter) and add the results (gather), or run them on an analytics copy |
| R16 friend search | The prefix search covers all learners | Scatter-gather, or a search index |
| R22 support console | One list over all shards, newest first | Take the newest rows from every shard and merge them. `OFFSET 100000` across shards would be very slow, so we would use keyset pagination ("show rows older than this one") |
| W05 achievements catch-up | Batch over all learners | Run it on every shard separately |

### 7.3 Read replicas and caching
| Where | Queries | Reason |
|---|---|---|
| **Primary** | W01 to W05 | All writes go to the primary |
| **Primary** | R02, R03, R04, R06, R11 | The learner must see their own latest XP, streak and next lesson right after a lesson. A replica may be a few seconds late. A new account must also be able to sign in at once |
| **Cache** | R01 (course path) | It almost never changes. Clear the cache when a course is edited |
| **Cache** | R12 (profile achievements) | It changes only when a badge is awarded (W05 or a lesson). Clear that learner's entry |
| **Cache with a short time limit** | R05 (leaderboard) | About 30 seconds late is acceptable and many learners look at it |
| **Read replica / analytics copy** | R07, R08, R09, R10, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R23, R24, R25 | They are reports or tools, they read a lot, and a small delay does not matter. This keeps them away from the primary |

### 7.4 Maintenance
- **Autovacuum on `lesson_attempts`:** the default starts after 20% of the rows changed, which is millions of rows. We would lower it for the newest partitions, for example `ALTER TABLE lesson_attempts_p_2026_12 SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.01);`. Old partitions do not change, so they need one `VACUUM (FREEZE, ANALYZE)` after the month closes. `TODO: our measured number of dead rows or the time of VACUUM on the large data, if we have it.`
- **Why VACUUM matters here:** our covering indexes only give Index Only Scans when the visibility map is up to date.
- **Archiving:** detach and dump partitions older than a limit (for example 24 months), then drop them, and keep a yearly summary table for the analytics team.
- **Summary tables:** heavy reports that do not need live data (R25 per country and hour, R24 per CEFR level, R18 course popularity) can be materialized views, refreshed every night with `REFRESH MATERIALIZED VIEW CONCURRENTLY` (it needs a unique index). We would only do this if a report still misses its target.
- **Statistics:** run `ANALYZE` after every big load, and after creating a new partition.

## 8. Conclusion
`TODO: after measuring, answer in 5 to 8 lines: Is our database ready for next year? How many of the 30 queries meet their target? Which queries do not and why? What are the remaining risks (for example data not fitting in memory, sort or hash spilling to disk, write cost of the 9 indexes on W01 and W02, the DEFAULT partition filling up)?`
