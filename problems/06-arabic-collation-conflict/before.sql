-- Matching an imported list of customer names (Arabic) against the customer table.
-- #Names is created in tempdb, which uses the server collation (SQL_Latin1_General_CP1_CI_AS);
-- FullNameAr is Arabic_CI_AS. Joining them raises "Cannot resolve the collation conflict", and the
-- common copy-paste fix is to put COLLATE on the table column, which makes the index unusable for seeks.
CREATE TABLE #Names (Name nvarchar(100) NOT NULL);
INSERT #Names (Name) VALUES (N'خديجة حداد'), (N'عائشة حداد'), (N'فاطمة حداد'), (N'خديجة صبري'),
                            (N'خديجة فهمي'), (N'عائشة صبري'), (N'عائشة فهمي'), (N'فاطمة صبري');
SELECT c.CustomerId, c.FullNameAr
FROM dbo.Customers c
JOIN #Names n ON c.FullNameAr COLLATE DATABASE_DEFAULT = n.Name
ORDER BY c.CustomerId;
DROP TABLE #Names;
