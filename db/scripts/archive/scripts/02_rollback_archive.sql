-- 02_rollback_archive.sql -- moves every object in [archive] back to [dbo]
DECLARE @sql nvarchar(max)=N'';
SELECT @sql += N'ALTER SCHEMA dbo TRANSFER archive.' + QUOTENAME(o.name) + N';' + CHAR(10)
FROM sys.objects o WHERE o.schema_id = SCHEMA_ID('archive') AND o.type IN ('P','FN','IF','TF','V');
PRINT @sql; EXEC sp_executesql @sql;
