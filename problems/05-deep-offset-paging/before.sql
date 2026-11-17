-- Admin grid, page 10,001 (50 rows per page), newest first. This is what EF Core Skip()/Take() generates.
-- SQL Server must produce and throw away 500,000 rows to return 50.
EXEC sp_executesql N'
SELECT o.OrderId, o.OrderDate, o.CustomerId, o.Status, o.TotalAmount
FROM dbo.Orders o
ORDER BY o.OrderDate DESC, o.OrderId DESC
OFFSET @Skip ROWS FETCH NEXT 50 ROWS ONLY;',
N'@Skip int', @Skip = 500000;
