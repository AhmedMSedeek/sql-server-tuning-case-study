-- Monthly sales report: orders and revenue per city for March 2025.
-- YEAR()/MONTH() wrap the column, so the OrderDate index cannot be used for a range seek.
EXEC sp_executesql N'
SELECT o.ShippingCity, COUNT(*) AS Orders, SUM(o.TotalAmount) AS Revenue
FROM dbo.Orders o
WHERE YEAR(o.OrderDate) = @Year AND MONTH(o.OrderDate) = @Month
GROUP BY o.ShippingCity
ORDER BY o.ShippingCity;',
N'@Year int, @Month int', @Year = 2025, @Month = 3;
