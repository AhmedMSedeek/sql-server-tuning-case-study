-- Chosen fix: key the index on (Status, ShippingCity) and include TotalAmount.
-- Rows then arrive already grouped by city, so the plan is "seek + stream aggregate" for EVERY status value:
-- no key lookups, no sort, no memory grant, so nothing left for a sniffed row estimate to get wrong.
-- Tried first: (Status) INCLUDE (ShippingCity, TotalAmount). That removed the lookups, but the plan compiled for
-- ~1,000 rows still sorted 1.86M rows in a 1 MB memory grant and spilled 15,870 pages to tempdb.
-- Other options considered: OPTION (RECOMPILE) (a compile on every dashboard refresh), OPTIMIZE FOR (fragile).
CREATE INDEX IX_Orders_Status ON dbo.Orders (Status, ShippingCity) INCLUDE (TotalAmount) WITH (DROP_EXISTING = ON);
