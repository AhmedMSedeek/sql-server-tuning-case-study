-- Widen the existing index instead of adding a second one on the same key.
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate) INCLUDE (ShippingCity, TotalAmount) WITH (DROP_EXISTING = ON);
