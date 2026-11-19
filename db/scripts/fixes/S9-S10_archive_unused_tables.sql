-- S9-S10_archive_unused_tables.sql
-- S9/S10: HRZones and HRZoneTime are empty and nothing in the database uses them; BikeHistory (2 rows) is superseded
-- by BikePart / Part / PartType. All three move to the [archive] schema, with their rows, the same way the GPX tables
-- were archived: reversible, and dropped later after a quarantine period.
-- Their foreign keys to dbo tables (HRZoneTime -> TrainingRide, BikeHistory -> Bike) are dropped so an archived row can
-- never block a delete; FK_HRZoneTime_HRZones moves with both tables.
-- This also settles S9 (manual keys) and S12 for BikeHistory's varchar columns.
-- API: if the EF model has entities for these tables, nothing breaks unless the code uses them; remove them the next
-- time you re-scaffold.
--
-- @Apply = 0 reports; @Apply = 1 archives. @Rollback = 1 (with @Apply = 1) moves them back and recreates the two FKs.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S9-S10_archive_unused_tables.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply    bit = 0;   -- 0 = report only, 1 = make the change
DECLARE @Rollback bit = 0;   -- 1 = move the tables back to dbo

IF SCHEMA_ID(N'archive') IS NULL
BEGIN
    RAISERROR(N'Schema [archive] not found (run the Archive phase first). Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @T TABLE (Seq int, Name sysname);
INSERT @T VALUES (1, N'HRZoneTime'), (2, N'HRZones'), (3, N'BikeHistory');

SELECT t.Name,
       CASE WHEN OBJECT_ID(N'dbo.' + QUOTENAME(t.Name), N'U') IS NOT NULL THEN N'dbo'
            WHEN OBJECT_ID(N'archive.' + QUOTENAME(t.Name), N'U') IS NOT NULL THEN N'archive' ELSE N'NOT FOUND' END AS SchemaNow,
       (SELECT SUM(p.row_count) FROM sys.dm_db_partition_stats AS p
        WHERE p.object_id = COALESCE(OBJECT_ID(N'dbo.' + QUOTENAME(t.Name), N'U'), OBJECT_ID(N'archive.' + QUOTENAME(t.Name), N'U'))
          AND p.index_id IN (0, 1)) AS [Rows]
FROM @T AS t ORDER BY t.Seq;

DECLARE @Users nvarchar(2000) = STUFF((
    SELECT DISTINCT N', ' + OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id)
    FROM sys.sql_expression_dependencies AS d
    WHERE d.referenced_entity_name IN (N'HRZoneTime', N'HRZones', N'BikeHistory')
      AND OBJECT_SCHEMA_NAME(d.referencing_id) = N'dbo'
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Users IS NOT NULL AND @Rollback = 0
BEGIN
    RAISERROR(N'Still used in dbo by %s. Nothing was changed.', 16, 1, @Users);
    RETURN;
END;

IF @Apply = 0
BEGIN
    PRINT CASE WHEN @Rollback = 1 THEN N'Nothing changed. Set @Apply = 1 to move the tables back to dbo.'
               ELSE N'Nothing changed. Set @Apply = 1 to move the tables to [archive].' END;
    RETURN;
END;

DECLARE @name sysname, @sql nvarchar(max);
BEGIN TRY
    BEGIN TRANSACTION;
    IF @Rollback = 0
    BEGIN
        -- foreign keys from these tables to tables that stay in dbo
        DECLARE f CURSOR LOCAL FAST_FORWARD FOR
            SELECT N'ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
            FROM sys.foreign_keys AS fk
            WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'dbo'
              AND OBJECT_NAME(fk.parent_object_id) IN (N'HRZoneTime', N'BikeHistory')
              AND OBJECT_NAME(fk.referenced_object_id) NOT IN (N'HRZoneTime', N'HRZones', N'BikeHistory');
        OPEN f; FETCH NEXT FROM f INTO @sql;
        WHILE @@FETCH_STATUS = 0 BEGIN PRINT @sql; EXEC sp_executesql @sql; FETCH NEXT FROM f INTO @sql; END;
        CLOSE f; DEALLOCATE f;

        DECLARE t CURSOR LOCAL FAST_FORWARD FOR SELECT Name FROM @T WHERE OBJECT_ID(N'dbo.' + QUOTENAME(Name), N'U') IS NOT NULL ORDER BY Seq;
        OPEN t; FETCH NEXT FROM t INTO @name;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'ALTER SCHEMA archive TRANSFER dbo.' + QUOTENAME(@name) + N';';
            PRINT @sql; EXEC sp_executesql @sql;
            INSERT archive.ArchiveLog (Note) VALUES (N'S9-S10: moved table dbo.' + @name + N' to archive');
            FETCH NEXT FROM t INTO @name;
        END;
        CLOSE t; DEALLOCATE t;
    END
    ELSE
    BEGIN
        DECLARE t CURSOR LOCAL FAST_FORWARD FOR SELECT Name FROM @T WHERE OBJECT_ID(N'archive.' + QUOTENAME(Name), N'U') IS NOT NULL ORDER BY Seq DESC;
        OPEN t; FETCH NEXT FROM t INTO @name;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'ALTER SCHEMA dbo TRANSFER archive.' + QUOTENAME(@name) + N';';
            PRINT @sql; EXEC sp_executesql @sql;
            INSERT archive.ArchiveLog (Note) VALUES (N'S9-S10 rollback: moved table archive.' + @name + N' back to dbo');
            FETCH NEXT FROM t INTO @name;
        END;
        CLOSE t; DEALLOCATE t;
        IF OBJECT_ID(N'dbo.HRZoneTime', N'U') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.HRZoneTime') AND referenced_object_id = OBJECT_ID(N'dbo.TrainingRide'))
            ALTER TABLE dbo.HRZoneTime WITH CHECK ADD CONSTRAINT FK_HRZoneTime_TrainingRide FOREIGN KEY (RideId) REFERENCES dbo.TrainingRide (Id);
        IF OBJECT_ID(N'dbo.BikeHistory', N'U') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.BikeHistory') AND referenced_object_id = OBJECT_ID(N'dbo.Bike'))
            ALTER TABLE dbo.BikeHistory WITH CHECK ADD CONSTRAINT FK_BikeHistory_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id);
    END;
    COMMIT;
    PRINT N'Done.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
