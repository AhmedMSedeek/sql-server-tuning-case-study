-- Simulates a normal morning: the plan is compiled by the dashboard's usual call (Pending: ~1,000 rows),
-- which makes "seek + key lookup" the right plan... for that value.
EXEC sp_recompile N'dbo.GetStatusSummary';
GO
EXEC dbo.GetStatusSummary @Status = 1;
