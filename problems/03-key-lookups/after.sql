-- Same query. With the index keyed (CustomerId, OrderDate DESC) and covering, SQL Server reads the 50 rows in order and stops.
EXEC sp_executesql N'
SELECT TOP (50) o.OrderId, o.OrderDate, o.Status, o.TotalAmount
FROM dbo.Orders o
WHERE o.CustomerId = @CustomerId
ORDER BY o.OrderDate DESC;',
N'@CustomerId int', @CustomerId = 14;
