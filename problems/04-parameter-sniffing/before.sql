-- Then the monthly report calls the same procedure for Delivered (~1.86 million rows) and reuses the cached
-- plan: 1.86 million key lookups instead of one scan.
EXEC dbo.GetStatusSummary @Status = 4;
