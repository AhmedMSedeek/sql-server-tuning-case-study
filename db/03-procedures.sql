/* Stored procedures the (fictional) back office calls. Part of the baseline, untuned. */
USE GrocerySouqPerf;
GO
-- Operations dashboard tile: "orders and revenue per city for status X".
-- Called all day with @Status = 1 (Pending, a few hundred rows); the monthly report calls it with 4 (Delivered).
CREATE OR ALTER PROCEDURE dbo.GetStatusSummary
    @Status tinyint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.ShippingCity, COUNT(*) AS Orders, SUM(o.TotalAmount) AS Revenue
    FROM dbo.Orders o
    WHERE o.Status = @Status
    GROUP BY o.ShippingCity
    ORDER BY o.ShippingCity;
END
GO
