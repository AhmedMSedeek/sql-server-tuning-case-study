# Benchmark results (2026-11-17)

Median of 10 warm runs per variant. Reads = logical reads; CPU = server CPU; Elapsed = client time incl. result transfer.

| Problem | Rows | Reads before | Reads after | CPU ms before | CPU ms after | Elapsed ms before | Elapsed ms after | Same result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 01-non-sargable-dates | 12 | 12,290 | 235 (52x) | 406 | 24 | 448.0 | 27.2 | yes |
| 02-implicit-conversion | 1 | 1,079 | 6 (180x) | 16 | 0 | 29.7 | 1.4 | yes |
| 03-key-lookups | 50 | 12,472 | 3 (4,157x) | 16 | 0 | 16.9 | 1.6 | yes |
| 04-parameter-sniffing | 12 | 5,695,700 | 8,428 (676x) | 4,063 | 493 | 5,830.6 | 520.5 | yes |
| 05-deep-offset-paging | 50 | 1,532,398 | 156 (9,823x) | 1,250 | 0 | 1,274.6 | 1.8 | yes |
| 06-arabic-collation-conflict | 5,327 | 815 | 62 (13x) | 63 | 0 | 80.3 | 19.0 | yes |
