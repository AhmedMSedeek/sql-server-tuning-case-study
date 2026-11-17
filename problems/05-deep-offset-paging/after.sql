-- Keyset ("seek") paging: the grid passes the sort key of the last row it showed
-- (here: the 500,000th row, 2025-11-01 15:11:53 / order 718074). Same 50 rows, read directly.
-- IX_Orders_OrderDate already contains OrderId (the clustered key), so no new index is needed.
EXEC sp_executesql N'
SELECT TOP (50) o.OrderId, o.OrderDate, o.CustomerId, o.Status, o.TotalAmount
FROM dbo.Orders o
WHERE o.OrderDate <= @LastDate
  AND (o.OrderDate < @LastDate OR o.OrderId < @LastId)
ORDER BY o.OrderDate DESC, o.OrderId DESC;',
N'@LastDate datetime2(0), @LastId int', @LastDate = '2025-11-01T15:11:53', @LastId = 718074;
