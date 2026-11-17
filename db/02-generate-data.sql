/* Deterministic data generator: same rows on every run (no RAND/NEWID).
   Sizes: 20 categories, 5,000 products, 200,000 customers, 2,000,000 orders, ~6,000,000 order lines.
   Distribution is intentionally realistic:
     - 20 "business" customers (ids 1-20) place 25% of all orders (25,000 each); everyone else ~8.
     - Status is skewed like a real shop: ~93% Delivered, 0.05% Pending (a small live queue),
       2% Paid, 4% Shipped, 1% Cancelled.
   Pseudo-random values come from h = (n * prime + offset) mod 2147483647. */
SET NOCOUNT ON;
USE GrocerySouqPerf;
GO

-- ---------------------------------------------------------------- categories
INSERT dbo.Categories (CategoryId, Name) VALUES
 (1,N'Rice & Grains'),(2,N'Dates & Dried Fruit'),(3,N'Oils'),(4,N'Honey & Spreads'),(5,N'Legumes'),
 (6,N'Tea & Coffee'),(7,N'Dairy'),(8,N'Bakery'),(9,N'Baking'),(10,N'Spices'),
 (11,N'Fresh Fruit'),(12,N'Vegetables'),(13,N'Halal Meat'),(14,N'Halal Poultry'),(15,N'Seafood'),
 (16,N'Frozen'),(17,N'Snacks'),(18,N'Beverages'),(19,N'Household'),(20,N'Personal Care');
GO

-- ---------------------------------------------------------------- products (5,000)
WITH L0 AS (SELECT 1 c FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(c)),
     L1 AS (SELECT 1 c FROM L0 a CROSS JOIN L0 b), L2 AS (SELECT 1 c FROM L1 a CROSS JOIN L1 b),
     N  AS (SELECT TOP (5000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS bigint) n FROM L2 a CROSS JOIN L1 b),
     Items AS (SELECT * FROM (VALUES
        (0,N'Basmati Rice',N'أرز بسمتي'),(1,N'Medjool Dates',N'تمر مجدول'),(2,N'Olive Oil',N'زيت زيتون'),
        (3,N'Sidr Honey',N'عسل سدر'),(4,N'Red Lentils',N'عدس أحمر'),(5,N'Green Tea',N'شاي أخضر'),
        (6,N'Fresh Milk',N'حليب طازج'),(7,N'Arabic Bread',N'خبز عربي'),(8,N'Flour',N'دقيق'),
        (9,N'Cumin',N'كمون'),(10,N'Oranges',N'برتقال'),(11,N'Tomatoes',N'طماطم'),
        (12,N'Lamb Chops',N'ريش ضأن'),(13,N'Chicken Breast',N'صدور دجاج'),(14,N'Sea Bream',N'دنيس'),
        (15,N'Frozen Okra',N'بامية مجمدة'),(16,N'Pistachios',N'فستق'),(17,N'Mango Juice',N'عصير مانجو'),
        (18,N'Dish Soap',N'صابون أطباق'),(19,N'Miswak',N'مسواك')) v(i, en, ar))
INSERT dbo.Products WITH (TABLOCK) (ProductId, Sku, Name, NameAr, CategoryId, Price, IsActive)
SELECT n,
       'SKU-' + RIGHT('000000' + CAST(n AS varchar(6)), 6),
       it.en + N' ' + CAST(1 + h1 % 25 AS nvarchar(3)) + N' pack #' + CAST(n AS nvarchar(6)),
       it.ar + N' ' + CAST(1 + h1 % 25 AS nvarchar(3)) + N' #' + CAST(n AS nvarchar(6)),
       CAST(1 + (n - 1) % 20 AS tinyint),
       CAST(1 + h2 % 50000 AS decimal(10,2)) / 100,
       CASE WHEN h1 % 20 = 0 THEN 0 ELSE 1 END
FROM N
CROSS APPLY (SELECT (n * 2654435761 + 1013904223) % 2147483647 AS h1,
                    (n * 1597334677 + 12345) % 2147483647      AS h2) h
JOIN Items it ON it.i = (n - 1) % 20;
GO

-- ---------------------------------------------------------------- customers (200,000)
WITH L0 AS (SELECT 1 c FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(c)),
     L1 AS (SELECT 1 c FROM L0 a CROSS JOIN L0 b), L2 AS (SELECT 1 c FROM L1 a CROSS JOIN L1 b),
     N  AS (SELECT TOP (200000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS bigint) n FROM L2 a CROSS JOIN L2 b),
     F  AS (SELECT * FROM (VALUES
        (0,'Youssef',N'يوسف'),(1,'Khaled',N'خالد'),(2,'Tarek',N'طارق'),(3,'Karim',N'كريم'),(4,'Hassan',N'حسن'),
        (5,'Ibrahim',N'إبراهيم'),(6,'Yahya',N'يحيى'),(7,'Bilal',N'بلال'),(8,'Hamza',N'حمزة'),(9,'Ziad',N'زياد'),
        (10,'Fatima',N'فاطمة'),(11,'Aisha',N'عائشة'),(12,'Khadija',N'خديجة'),(13,'Mariam',N'مريم'),(14,'Salma',N'سلمى'),
        (15,'Nour',N'نور'),(16,'Huda',N'هدى'),(17,'Rana',N'رنا'),(18,'Laila',N'ليلى'),(19,'Sara',N'سارة')) v(i, en, ar)),
     L  AS (SELECT * FROM (VALUES
        (0,'Haddad',N'حداد'),(1,'Saleh',N'صالح'),(2,'Farouk',N'فاروق'),(3,'Kamal',N'كمال'),(4,'Rashid',N'رشيد'),
        (5,'Zaki',N'زكي'),(6,'Shams',N'شمس'),(7,'Darwish',N'درويش'),(8,'Fahmy',N'فهمي'),(9,'Mansour',N'منصور'),
        (10,'Sabry',N'صبري'),(11,'Taher',N'طاهر'),(12,'Wahba',N'وهبة'),(13,'Gaber',N'جابر'),(14,'Lotfy',N'لطفي')) v(i, en, ar)),
     C  AS (SELECT * FROM (VALUES
        (0,N'Cairo'),(1,N'Alexandria'),(2,N'Giza'),(3,N'Mansoura'),(4,N'Tanta'),(5,N'Aswan'),
        (6,N'Riyadh'),(7,N'Jeddah'),(8,N'Dammam'),(9,N'Dubai'),(10,N'Doha'),(11,N'Kuwait City')) v(i, name))
INSERT dbo.Customers WITH (TABLOCK) (CustomerId, FullName, FullNameAr, Email, Phone, City, CreatedAt)
SELECT n,
       CASE WHEN n <= 20 THEN N'Business Account ' + CAST(n AS nvarchar(3)) ELSE f.en + N' ' + l.en END,
       CASE WHEN n <= 20 THEN N'حساب تجاري ' + CAST(n AS nvarchar(3)) ELSE f.ar + N' ' + l.ar END,
       LOWER(f.en) + '.' + LOWER(l.en) + CAST(n AS varchar(7)) + '@example.com',
       '+20' + RIGHT('0000000000' + CAST(h3 % 10000000000 AS varchar(11)), 10),
       c.name,
       DATEADD(SECOND, CAST(h3 % 94608000 AS int), CAST('2020-01-01' AS datetime2(0)))
FROM N
CROSS APPLY (SELECT (n * 2654435761 + 7) % 2147483647 AS h1,
                    (n * 2246822519 + 3) % 2147483647 AS h2,
                    (n * 3266489917 + 1) % 2147483647 AS h3) h
JOIN F f ON f.i = h1 % 20
JOIN L l ON l.i = h2 % 15
JOIN C c ON c.i = h3 % 12;
GO

-- ---------------------------------------------------------------- orders (2,000,000)
WITH L0 AS (SELECT 1 c FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(c)),
     L1 AS (SELECT 1 c FROM L0 a CROSS JOIN L0 b), L2 AS (SELECT 1 c FROM L1 a CROSS JOIN L1 b),
     N  AS (SELECT TOP (2000000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS bigint) n FROM L2 a CROSS JOIN L2 b),
     C  AS (SELECT * FROM (VALUES
        (0,N'Cairo'),(1,N'Alexandria'),(2,N'Giza'),(3,N'Mansoura'),(4,N'Tanta'),(5,N'Aswan'),
        (6,N'Riyadh'),(7,N'Jeddah'),(8,N'Dammam'),(9,N'Dubai'),(10,N'Doha'),(11,N'Kuwait City')) v(i, name))
INSERT dbo.Orders WITH (TABLOCK) (OrderId, CustomerId, OrderDate, Status, ShippingCity, TotalAmount)
SELECT n,
       CASE WHEN h1 % 100 < 25 THEN 1 + h2 % 20 ELSE 21 + h2 % 199980 END,
       -- 2023-01-01 .. 2026-10-31 (1,400 days)
       DATEADD(SECOND, CAST(h3 % 120960000 AS int), CAST('2023-01-01' AS datetime2(0))),
       CASE WHEN h4 % 10000 < 5 THEN 1 WHEN h4 % 10000 < 205 THEN 2 WHEN h4 % 10000 < 605 THEN 3
            WHEN h4 % 10000 < 705 THEN 5 ELSE 4 END,
       c.name,
       0
FROM N
CROSS APPLY (SELECT (n * 2654435761 + 11) % 2147483647 AS h1,
                    (n * 2246822519 + 13) % 2147483647 AS h2,
                    (n * 3266489917 + 17) % 2147483647 AS h3,
                    (n * 668265263  + 19) % 2147483647 AS h4) h
JOIN C c ON c.i = FLOOR(h2 / 7) % 12;  -- the hashes are decimal: FLOOR keeps the division integral
GO

-- ---------------------------------------------------------------- order lines (1-5 per order, ~6,000,000)
WITH Lines AS (SELECT * FROM (VALUES (1),(2),(3),(4),(5)) v(LineNumber))
INSERT dbo.OrderLines WITH (TABLOCK) (OrderId, LineNumber, ProductId, Quantity, UnitPrice)
SELECT o.OrderId, CAST(l.LineNumber AS tinyint), p.ProductId, CAST(1 + h.q % 6 AS smallint), p.Price
FROM dbo.Orders o
CROSS JOIN Lines l
CROSS APPLY (SELECT (CAST(o.OrderId AS bigint) * 2654435761 + 23) % 2147483647 AS cnt,
                    ((CAST(o.OrderId AS bigint) * 10 + l.LineNumber) * 2246822519 + 29) % 2147483647 AS prod,
                    ((CAST(o.OrderId AS bigint) * 10 + l.LineNumber) * 3266489917 + 31) % 2147483647 AS q) h
JOIN dbo.Products p ON p.ProductId = 1 + h.prod % 5000
WHERE l.LineNumber <= 1 + h.cnt % 5;
GO

UPDATE o SET TotalAmount = t.Total
FROM dbo.Orders o
JOIN (SELECT OrderId, SUM(Quantity * UnitPrice) AS Total FROM dbo.OrderLines GROUP BY OrderId) t ON t.OrderId = o.OrderId;
GO

-- ---------------------------------------------------------------- foreign keys + the "typical" untuned indexes
ALTER TABLE dbo.Orders     ADD CONSTRAINT FK_Orders_Customers     FOREIGN KEY (CustomerId) REFERENCES dbo.Customers;
ALTER TABLE dbo.OrderLines ADD CONSTRAINT FK_OrderLines_Orders    FOREIGN KEY (OrderId)    REFERENCES dbo.Orders;
ALTER TABLE dbo.OrderLines ADD CONSTRAINT FK_OrderLines_Products  FOREIGN KEY (ProductId)  REFERENCES dbo.Products;

CREATE UNIQUE INDEX IX_Customers_Email      ON dbo.Customers (Email);
CREATE INDEX IX_Customers_FullNameAr        ON dbo.Customers (FullNameAr);
CREATE INDEX IX_Orders_CustomerId           ON dbo.Orders (CustomerId);
CREATE INDEX IX_Orders_OrderDate            ON dbo.Orders (OrderDate);
CREATE INDEX IX_Orders_Status               ON dbo.Orders (Status);
CREATE INDEX IX_OrderLines_ProductId        ON dbo.OrderLines (ProductId);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.OrderLines WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO

SELECT 'Categories' t, COUNT_BIG(*) n FROM dbo.Categories UNION ALL
SELECT 'Products', COUNT_BIG(*) FROM dbo.Products UNION ALL
SELECT 'Customers', COUNT_BIG(*) FROM dbo.Customers UNION ALL
SELECT 'Orders', COUNT_BIG(*) FROM dbo.Orders UNION ALL
SELECT 'OrderLines', COUNT_BIG(*) FROM dbo.OrderLines;
SELECT Status, COUNT(*) n FROM dbo.Orders GROUP BY Status ORDER BY Status;
SELECT TOP (3) CustomerId, COUNT(*) n FROM dbo.Orders GROUP BY CustomerId ORDER BY n DESC;
GO
