# SQL Server performance tuning case study

Six real-world SQL Server performance problems, on a 2-million-order e-commerce database, each diagnosed from its execution plan, fixed, and **proven** with a repeatable before/after benchmark that also checks the fix returns exactly the same rows.

| Problem | Before | After |
|---|---|---|
| Deep `OFFSET` paging (EF Core `Skip/Take`) | 1,532,398 reads · 1,275 ms | **156 reads · 1.8 ms** |
| Parameter sniffing + tempdb spill | 5,695,700 reads · 5.8 s | **8,428 reads · 0.52 s** |
| Key lookups on large accounts | 12,472 reads | **3 reads** |
| Implicit conversion (.NET `nvarchar` vs `varchar`) | 1,079 reads | **6 reads** |
| Non-SARGable `YEAR()/MONTH()` filter | 12,290 reads · 448 ms | **235 reads · 27 ms** |
| Arabic collation conflict with a temp table | 815 reads · 80 ms | **62 reads · 19 ms** |

No new indexes added: three were re-keyed or widened in place, and three fixes are query or application changes.

📄 **Full write-up: [TUNING-REPORT.md](TUNING-REPORT.md)**: cause, fix and evidence for each problem, including a "first fix wasn't enough" case.

## Reproduce
Requires SQL Server 2019+ (LocalDB is enough) and PowerShell.
```powershell
$env:DataDir = "C:\SqlData"   # folder for the .mdf/.ldf (about 2 GB)
sqlcmd -S "(localdb)\MSSQLLocalDB" -f 65001 -i db\01-create-database.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -f 65001 -t 0 -i db\02-generate-data.sql   # ~2 minutes
sqlcmd -S "(localdb)\MSSQLLocalDB" -f 65001 -i db\03-procedures.sql
powershell -ExecutionPolicy Bypass -File bench\Run-Benchmark.ps1 -Runs 10
```
The data generator is deterministic: every run builds the same 2,000,000 orders.

## Layout
- `db/`: schema, data generator, procedures
- `problems/NN-*/`: `before.sql`, `after.sql`, `fix.sql`, `unfix.sql` (+ `prime.sql`)
- `bench/Run-Benchmark.ps1`: benchmark and result verification
- `results/`: numbers and actual execution plans (`.sqlplan`)

MIT licensed. All data is synthetic; email addresses use the reserved `example.com` domain.
