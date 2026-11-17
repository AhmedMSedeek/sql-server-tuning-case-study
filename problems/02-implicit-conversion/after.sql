-- Same query with the parameter typed like the column (varchar(200)): a single index seek.
-- The fix is in the application, not the database. See TUNING-REPORT.md for the C# / EF Core change.
EXEC sp_executesql N'SELECT c.CustomerId, c.FullName, c.City FROM dbo.Customers c WHERE c.Email = @Email;',
    N'@Email varchar(200)', @Email = 'rana.wahba123457@example.com';
