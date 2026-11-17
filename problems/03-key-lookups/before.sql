-- "My orders" page, first 50 orders, for one of the business accounts (25,000 orders).
-- IX_Orders_CustomerId finds the rows, but every row needs a key lookup for OrderDate/Status/TotalAmount,
-- then all 25,000 rows are sorted to return 50.
EXEC sp_executesql N'
SELECT TOP (50) o.OrderId, o.OrderDate, o.Status, o.TotalAmount
FROM dbo.Orders o
WHERE o.CustomerId = @CustomerId
ORDER BY o.OrderDate DESC;',
N'@CustomerId int', @CustomerId = 14;
