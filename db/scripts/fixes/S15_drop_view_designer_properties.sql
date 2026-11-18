-- S15_drop_view_designer_properties.sql
-- Drops the MS_DiagramPane1 / MS_DiagramPane2 / MS_DiagramPaneCount extended properties that the SSMS view designer
-- left on the views (24 on 9 views). They are layout data only; removing them changes no view and no data.
-- They are already gone from the SQL project, so afterwards a DeployReport against this database shows no differences.
--
-- @Apply = 0 lists what would be dropped; @Apply = 1 drops them.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S15_drop_view_designer_properties.sql

SET NOCOUNT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = drop

DECLARE @Props TABLE (SchemaName sysname, ViewName sysname, PropName sysname);
INSERT @Props (SchemaName, ViewName, PropName)
SELECT OBJECT_SCHEMA_NAME(ep.major_id), OBJECT_NAME(ep.major_id), ep.name
FROM sys.extended_properties AS ep
JOIN sys.views AS v ON v.object_id = ep.major_id
WHERE ep.class = 1 AND ep.minor_id = 0 AND ep.name LIKE N'MS[_]Diagram%';

SELECT SchemaName, ViewName, PropName FROM @Props ORDER BY SchemaName, ViewName, PropName;
DECLARE @Count int = (SELECT COUNT(*) FROM @Props);
PRINT CONCAT(N'Designer properties found: ', @Count);

IF @Apply = 0
BEGIN
    PRINT N'Nothing changed. Set @Apply = 1 to drop them.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @s sysname, @v sysname, @p sysname;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT SchemaName, ViewName, PropName FROM @Props;
    OPEN c; FETCH NEXT FROM c INTO @s, @v, @p;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_dropextendedproperty @name = @p, @level0type = N'SCHEMA', @level0name = @s,
                                         @level1type = N'VIEW', @level1name = @v;
        FETCH NEXT FROM c INTO @s, @v, @p;
    END;
    CLOSE c; DEALLOCATE c;
    COMMIT;
    PRINT CONCAT(N'Dropped ', @Count, N' designer properties.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
