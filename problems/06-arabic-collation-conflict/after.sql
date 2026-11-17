-- Give the temp table the column's collation (or put COLLATE on the #Names side): the index on
-- FullNameAr is used for 8 seeks instead of a scan of every customer.
CREATE TABLE #Names (Name nvarchar(100) COLLATE Arabic_CI_AS NOT NULL);
INSERT #Names (Name) VALUES (N'خديجة حداد'), (N'عائشة حداد'), (N'فاطمة حداد'), (N'خديجة صبري'),
                            (N'خديجة فهمي'), (N'عائشة صبري'), (N'عائشة فهمي'), (N'فاطمة صبري');
SELECT c.CustomerId, c.FullNameAr
FROM dbo.Customers c
JOIN #Names n ON c.FullNameAr = n.Name
ORDER BY c.CustomerId;
DROP TABLE #Names;
