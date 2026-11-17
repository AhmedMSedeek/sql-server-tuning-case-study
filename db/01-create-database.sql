/* GrocerySouq performance case study: database and schema.
   Run with sqlcmd:  sqlcmd -S "(localdb)\MSSQLLocalDB" -i db\01-create-database.sql -v DataDir="C:\path\to\folder"
   The schema is what a typical small e-commerce back office looks like: sensible primary keys,
   one single-column index per foreign key / filter column, and nothing tuned yet. */
SET NOCOUNT ON;
USE master;
IF DB_ID(N'GrocerySouqPerf') IS NOT NULL
BEGIN
    ALTER DATABASE GrocerySouqPerf SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GrocerySouqPerf;
END
GO
CREATE DATABASE GrocerySouqPerf
    ON (NAME = GrocerySouqPerf, FILENAME = '$(DataDir)\GrocerySouqPerf.mdf', SIZE = 1024MB, FILEGROWTH = 256MB)
    LOG ON (NAME = GrocerySouqPerf_log, FILENAME = '$(DataDir)\GrocerySouqPerf_log.ldf', SIZE = 512MB, FILEGROWTH = 256MB);
GO
ALTER DATABASE GrocerySouqPerf SET RECOVERY SIMPLE;
ALTER DATABASE GrocerySouqPerf SET COMPATIBILITY_LEVEL = 150;  -- SQL Server 2019
GO
USE GrocerySouqPerf;
GO
CREATE TABLE dbo.Categories (
    CategoryId tinyint      NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
    Name       nvarchar(50) NOT NULL
);

CREATE TABLE dbo.Products (
    ProductId  int           NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    Sku        varchar(20)   NOT NULL CONSTRAINT UQ_Products_Sku UNIQUE,
    Name       nvarchar(100) NOT NULL,
    NameAr     nvarchar(100) COLLATE Arabic_CI_AS NOT NULL,
    CategoryId tinyint       NOT NULL CONSTRAINT FK_Products_Categories REFERENCES dbo.Categories,
    Price      decimal(10,2) NOT NULL,
    IsActive   bit           NOT NULL
);

CREATE TABLE dbo.Customers (
    CustomerId int           NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    FullName   nvarchar(100) NOT NULL,
    FullNameAr nvarchar(100) COLLATE Arabic_CI_AS NOT NULL,
    Email      varchar(200)  NOT NULL,   -- varchar: emails are ASCII. (Matters for problem 02.)
    Phone      varchar(20)   NOT NULL,
    City       nvarchar(50)  NOT NULL,
    CreatedAt  datetime2(0)  NOT NULL
);

CREATE TABLE dbo.Orders (
    OrderId      int           NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId   int           NOT NULL,
    OrderDate    datetime2(0)  NOT NULL,
    Status       tinyint       NOT NULL,  -- 1 Pending, 2 Paid, 3 Shipped, 4 Delivered, 5 Cancelled
    ShippingCity nvarchar(50)  NOT NULL,
    TotalAmount  decimal(12,2) NOT NULL
);

CREATE TABLE dbo.OrderLines (
    OrderId   int           NOT NULL,
    LineNumber    tinyint       NOT NULL,
    ProductId int           NOT NULL,
    Quantity  smallint      NOT NULL,
    UnitPrice decimal(10,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderId, LineNumber)
);
GO
