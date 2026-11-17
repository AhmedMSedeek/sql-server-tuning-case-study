CREATE INDEX IX_Orders_CustomerId ON dbo.Orders (CustomerId, OrderDate DESC) INCLUDE (Status, TotalAmount) WITH (DROP_EXISTING = ON);
