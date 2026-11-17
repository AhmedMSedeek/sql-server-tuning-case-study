-- Login lookup as sent by .NET: a C# string becomes nvarchar(4000) by default (SqlClient AddWithValue,
-- Dapper, EF Core when the column is not mapped as non-Unicode). The column is varchar(200), so SQL Server
-- converts the column, not the parameter: CONVERT_IMPLICIT on every row = index scan.
EXEC sp_executesql N'SELECT c.CustomerId, c.FullName, c.City FROM dbo.Customers c WHERE c.Email = @Email;',
    N'@Email nvarchar(4000)', @Email = N'rana.wahba123457@example.com';
