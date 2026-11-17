# SQL Server tuning report: GrocerySouq back office

**System:** an online grocery store's order database. SQL Server 2019, 200,000 customers, 2,000,000 orders, 6,000,000 order lines (486 MB).
**Complaint (typical brief):** "Reports are slow, the admin grid times out on later pages, the monthly report sometimes takes forever, and the database server's CPU is high."
**Result:** six root causes found and fixed. Every fix was verified to return **exactly the same rows** (SHA-256 of the full result set).

## 1. Summary

| # | Problem | Logical reads | Server CPU | Response time | Fix type |
|---|---|---|---|---|---|
| 01 | Non-SARGable date filter in the monthly report | 12,290 → 235 (**52×**) | 406 → 24 ms | 448 → 27 ms | Query rewrite + widen existing index |
| 02 | Implicit conversion on login lookup (.NET sends `nvarchar`) | 1,079 → 6 (**180×**) | 16 → 0 ms | 30 → 1.4 ms | Application parameter type |
| 03 | "My orders" page for large accounts | 12,472 → 3 (**4,157×**) | 16 → 0 ms | 17 → 1.6 ms | Replace an index (same count) |
| 04 | Parameter sniffing in the dashboard procedure | 5,695,700 → 8,428 (**676×**) | 4,063 → 493 ms | 5.8 s → 0.52 s | Re-key an existing index |
| 05 | Deep `OFFSET` paging in the admin grid | 1,532,398 → 156 (**9,823×**) | 1,250 → 0 ms | 1,275 → 1.8 ms | Keyset paging (no schema change) |
| 06 | Arabic collation conflict with a temp table | 815 → 62 (**13×**) | 63 → 0 ms | 80 → 19 ms | Query fix (no schema change) |

**No new indexes were added.** Three existing indexes were widened or re-keyed in place (`DROP_EXISTING`), and the other three problems were fixed in queries or application code. Write overhead grows only slightly (wider rows in three existing indexes).

How measured: median of 10 warm runs per variant (`bench/Run-Benchmark.ps1`). Logical reads from `SET STATISTICS IO`; CPU from `sys.dm_exec_sessions`; response time = client time including result transfer. Machine: 4-core VM, SQL Server 2019 Express LocalDB. Absolute times will differ on production hardware, but logical reads (the work done) will not. Raw numbers: `results/benchmark-2026-11-17.md`; actual execution plans: `results/plans/*.sqlplan`.

---

## 2. Findings

### 01: Non-SARGable date filter (monthly sales report)
**Symptom:** the monthly report scans the whole `Orders` table (2M rows) even though `OrderDate` is indexed.
**Cause:** `WHERE YEAR(OrderDate) = @Year AND MONTH(OrderDate) = @Month` wraps the column in functions, so SQL Server cannot seek into the index.
**Fix:**
```sql
WHERE o.OrderDate >= @From AND o.OrderDate < DATEADD(MONTH, 1, @From)
```
plus `IX_Orders_OrderDate` widened with `INCLUDE (ShippingCity, TotalAmount)`.
**Both parts are needed** (measured): the rewrite alone still reads 12,290 pages (a 45k-row range needs a key lookup per row, so a scan is still cheaper); the index alone still reads 10,305 (it scans the narrower index). Together: **235 reads, 27 ms**.

### 02: Implicit conversion (login / customer lookup by email)
**Symptom:** a single-row lookup by a uniquely indexed email reads 1,079 pages; the plan carries the warning *"Type conversion … may affect 'SeekPlan'"*.
**Cause:** `Email` is `varchar(200)`, but .NET sends strings as `nvarchar(4000)` by default (`AddWithValue`, Dapper, and EF Core when the property isn't mapped as non-Unicode). SQL Server converts **the column** on every row, so it scans the index instead of seeking.
**Fix (application, no database change):**
```csharp
// ADO.NET
cmd.Parameters.Add("@Email", SqlDbType.VarChar, 200).Value = email;
// Dapper
new { Email = new DbString { Value = email, IsAnsi = true, Length = 200 } }
// EF Core model configuration
builder.Property(c => c.Email).IsUnicode(false).HasMaxLength(200);
```
**Result:** 6 reads, 1.4 ms. The saving per call is small, but this query runs on every login; under load the scan version costs **180× the I/O** for every call.

### 03: Customer order history for large accounts
**Symptom:** the "My orders" page (latest 50 orders) is fine for normal customers but slow for the 20 business accounts (25,000 orders each).
**Cause:** the plan walks `IX_Orders_OrderDate` newest-first and does a key lookup on every order to check whether it belongs to this customer: 4,068 lookups to find 50 rows.
**Fix:** replace `IX_Orders_CustomerId (CustomerId)` with `(CustomerId, OrderDate DESC) INCLUDE (Status, TotalAmount)`. The 50 rows are now read in order from one index, and the query stops there.
**Result:** 12,472 → **3 reads**.

### 04: Parameter sniffing (dashboard procedure)
**Symptom:** `dbo.GetStatusSummary` is instant all day, but "sometimes takes forever", usually when the monthly report calls it.
**Cause:** the plan is compiled for the first call of the day, `@Status = 1` (Pending, ~1,000 rows): *seek + key lookup*. The report then calls it with `@Status = 4` (Delivered, 1.86M rows) and reuses that plan: **1.86 million key lookups**, plus a sort sized for 1,002 rows that **spills to tempdb**.
**First fix tried, and why it wasn't enough:** a covering index `(Status) INCLUDE (ShippingCity, TotalAmount)` removed the lookups (13,714 reads) but still took **3.5 s**. The plan still sorted 1.86M rows in a **1 MB memory grant** and spilled 15,870 pages to tempdb.
**Final fix:** key the index on `(Status, ShippingCity) INCLUDE (TotalAmount)`. Rows now arrive grouped by city, so the plan is *seek + stream aggregate* for every status value, with no lookups, no sort, no memory grant and nothing left for a sniffed estimate to get wrong.
**Result:** 5.8 s → **0.52 s** (the remaining time is aggregating 1.86M rows). The same plan is good for both values.
*Not chosen:* `OPTION (RECOMPILE)` (pays a compile on every dashboard refresh) and `OPTIMIZE FOR` (breaks when the data changes).

### 05: Deep OFFSET paging (admin grid)
**Symptom:** the orders grid is fast on page 1 and takes over a second on page 10,000. It gets slower as the table grows.
**Cause:** `OFFSET 500000 ROWS FETCH NEXT 50` (what EF Core `Skip()/Take()` generates) makes SQL Server read and discard 500,050 rows, each with a key lookup.
**Fix (no schema change):** keyset paging. The grid passes the sort key of the last row it showed:
```sql
WHERE o.OrderDate <= @LastDate AND (o.OrderDate < @LastDate OR o.OrderId < @LastId)
ORDER BY o.OrderDate DESC, o.OrderId DESC  -- TOP (50)
```
The existing `IX_Orders_OrderDate` already carries `OrderId` (the clustered key), so no index was needed.
**Result:** 1,532,398 → **156 reads**, 1,275 → **1.8 ms**, and the cost no longer grows with the page number. (Trade-off: "jump to page N" becomes "next/previous"; most admin grids only need that.)

### 06: Arabic collation conflict (name matching import)
**Symptom:** matching an imported list of Arabic customer names scans the whole name index.
**Cause:** the temp table lives in tempdb with the server collation (`SQL_Latin1_General_CP1_CI_AS`); `FullNameAr` is `Arabic_CI_AS`. The join fails with *"Cannot resolve the collation conflict"*, and the common copy-paste fix, `c.FullNameAr COLLATE DATABASE_DEFAULT = n.Name`, converts **the indexed column**, so the index can only be scanned.
**Fix:** put the collation on the temp table instead: `Name nvarchar(100) COLLATE Arabic_CI_AS`. The index is used for 8 seeks.
**Result:** 815 → **62 reads**, 80 → 19 ms. The gap grows with the customer table. Common in Arabic/English systems where the server and database collations differ.

---

## 3. How these were found (what I check on a client's server)
1. **Top queries by CPU and reads** from Query Store / `sys.dm_exec_query_stats`, not guesses.
2. **Actual execution plans** of the worst ones: warnings (`PlanAffectingConvert`, spills), key lookups with high row counts, estimated vs actual rows.
3. **Parameter-sensitive procedures:** compare plans for typical vs extreme parameter values.
4. **Application code paths** behind them (ORM paging, parameter types, temp tables).
5. Each fix proven with before/after logical reads **and** identical results.

## 4. Deliverables in this repo
- `problems/NN-*/`: for each finding, `before.sql`, `after.sql`, `fix.sql` and `unfix.sql` (plus `prime.sql` for sniffing)
- `bench/Run-Benchmark.ps1`: repeatable before/after benchmark with result-hash verification
- `results/`: benchmark table and CSV, actual execution plans (`.sqlplan`, open in SSMS)
- `db/`: schema and deterministic data generator (reproduces the exact database)

## 5. Recommended next steps (not done)
- Enable Query Store in production (if not already) to catch regressions after deployments.
- Review the remaining single-column foreign-key indexes for the same covering opportunities.
- Map every `varchar` column as `IsUnicode(false)` in the EF Core model, not just `Email`.
