-- Same report, half-open date range: SARGable, so it seeks into the (now covering) OrderDate index.
EXEC sp_executesql N'
SELECT o.ShippingCity, COUNT(*) AS Orders, SUM(o.TotalAmount) AS Revenue
FROM dbo.Orders o
WHERE o.OrderDate >= @From AND o.OrderDate < DATEADD(MONTH, 1, @From)
GROUP BY o.ShippingCity
ORDER BY o.ShippingCity;',
N'@From datetime2(0)', @From = '2025-03-01';
