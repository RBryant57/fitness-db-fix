-- rebuild_RecreationalRide.sql
-- S5 for dbo.RecreationalRide: rebuilds the table so that Duration after EndTime, BikeDuration after BikeEndTime, RestDuration after BikeDuration, as in tables/RecreationalRide.sql.
-- The stored RideTimeHours, RideTimeMinutes, RideTimeSeconds, BikeTimeHours, BikeTimeMinutes, BikeTimeSeconds columns are not carried over.
-- ALTER TABLE can only add a column at the end, so placing the computed column after its end time means
-- creating the table fresh and copying the rows across (what the SSMS table designer does).
--
-- In one transaction:
--   1. records the foreign keys in other tables that reference dbo.RecreationalRide, then drops them;
--   2. renames the table to RecreationalRide_Old (and its constraints to <name>_Old);
--   3. creates dbo.RecreationalRide from tables/RecreationalRide.sql, with the original constraint names;
--   4. copies every row (Id values kept, IDENTITY_INSERT), keeps the identity seed, drops RecreationalRide_Old, and
--      recreates any other nonclustered indexes the live table has, exactly as they are now;
--   5. recreates the referencing foreign keys (trusted or not trusted, as they were) and refreshes the views.
-- The new table's constraints are all checked (trusted). In the dacpac several foreign keys are not trusted, so old
-- rows were never checked against them; the checks below list any row that would fail, before anything changes.
--
-- Checks first (nothing changes if one fails):
--   * rows whose stored duration differs from the times (those stored values are lost; up to 50 listed);
--   * any view, procedure or function in dbo that still uses the old columns;
--   * rows that would break a constraint of the new table (missing parent rows, failed CHECKs);
--   * columns or triggers on the live table that tables/RecreationalRide.sql doesn't have, and indexes that use the old
--     duration columns or are not nonclustered rowstore (other indexes are carried over automatically);
--   * a leftover dbo.RecreationalRide_Old from an earlier failed run.
-- Object-level GRANTs on the table would be lost; 04_permissions.sql grants at schema level, so there are none.
--
-- Run order: procedure steps (00c, 00b, 01) -> revised views -> this script (@Apply = 0, then 1) -> deploy the API.
-- sqlcmd -S <server> -d Fitness -E -I -b -i rebuild_RecreationalRide.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'Run this in the Fitness database. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply              bit = 0;   -- 0 = report and check only, 1 = rebuild the table
DECLARE @DropEvenIfDisagree bit = 0;   -- 1 = rebuild even where stored durations differ from the times

DECLARE @n int, @Problems nvarchar(max) = N'', @sql nvarchar(max);

IF OBJECT_ID(N'dbo.RecreationalRide', N'U') IS NULL
BEGIN
    RAISERROR(N'dbo.RecreationalRide not found. Nothing was changed.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.RecreationalRide') AND name IN (N'RideTimeHours', N'RideTimeMinutes', N'RideTimeSeconds', N'BikeTimeHours', N'BikeTimeMinutes', N'BikeTimeSeconds'))
   AND (SELECT TOP (1) c2.name FROM sys.columns c1 JOIN sys.columns c2 ON c2.object_id = c1.object_id AND c2.column_id > c1.column_id WHERE c1.object_id = OBJECT_ID(N'dbo.RecreationalRide') AND c1.name = N'EndTime' ORDER BY c2.column_id) = N'Duration' AND (SELECT TOP (1) c2.name FROM sys.columns c1 JOIN sys.columns c2 ON c2.object_id = c1.object_id AND c2.column_id > c1.column_id WHERE c1.object_id = OBJECT_ID(N'dbo.RecreationalRide') AND c1.name = N'BikeEndTime' ORDER BY c2.column_id) = N'BikeDuration' AND (SELECT TOP (1) c2.name FROM sys.columns c1 JOIN sys.columns c2 ON c2.object_id = c1.object_id AND c2.column_id > c1.column_id WHERE c1.object_id = OBJECT_ID(N'dbo.RecreationalRide') AND c1.name = N'BikeDuration' ORDER BY c2.column_id) = N'RestDuration'
BEGIN
    PRINT N'dbo.RecreationalRide already has the new layout (Duration after EndTime, BikeDuration after BikeEndTime, RestDuration after BikeDuration). Nothing to do.';
    RETURN;
END;

-- Check 1: stored durations that differ from the times

IF COL_LENGTH(N'dbo.RecreationalRide', N'RideTimeHours') IS NOT NULL AND COL_LENGTH(N'dbo.RecreationalRide', N'RideTimeMinutes') IS NOT NULL AND COL_LENGTH(N'dbo.RecreationalRide', N'RideTimeSeconds') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);',
                       N'@n int OUTPUT', @n = @n OUTPUT;
    PRINT CONCAT(N'RideTime*: ', @n, N' row(s) where the stored duration differs from StartTime -> EndTime');
    IF @n > 0
    BEGIN
        EXEC (N'SELECT TOP (50) Id, [Date], StartTime, EndTime,
                   CONCAT(RideTimeHours, '':'', RIGHT(CONCAT(''0'', RideTimeMinutes), 2), '':'', RIGHT(CONCAT(''0'', RideTimeSeconds), 2)) AS StoredRideTime,
                   DATEDIFF(second, StartTime, EndTime) AS SecondsFromTimes
                FROM dbo.RecreationalRide
                WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        IF @DropEvenIfDisagree = 0
            SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) where RideTime* differs from StartTime -> EndTime (set @DropEvenIfDisagree = 1 to accept)');
    END;
END;

IF COL_LENGTH(N'dbo.RecreationalRide', N'BikeTimeHours') IS NOT NULL AND COL_LENGTH(N'dbo.RecreationalRide', N'BikeTimeMinutes') IS NOT NULL AND COL_LENGTH(N'dbo.RecreationalRide', N'BikeTimeSeconds') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds <> DATEDIFF(second, StartTime, BikeEndTime);',
                       N'@n int OUTPUT', @n = @n OUTPUT;
    PRINT CONCAT(N'BikeTime*: ', @n, N' row(s) where the stored duration differs from StartTime -> BikeEndTime');
    IF @n > 0
    BEGIN
        EXEC (N'SELECT TOP (50) Id, [Date], StartTime, BikeEndTime,
                   CONCAT(BikeTimeHours, '':'', RIGHT(CONCAT(''0'', BikeTimeMinutes), 2), '':'', RIGHT(CONCAT(''0'', BikeTimeSeconds), 2)) AS StoredBikeTime,
                   DATEDIFF(second, StartTime, BikeEndTime) AS SecondsFromTimes
                FROM dbo.RecreationalRide
                WHERE BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds <> DATEDIFF(second, StartTime, BikeEndTime) ORDER BY [Date];');
        IF @DropEvenIfDisagree = 0
            SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) where BikeTime* differs from StartTime -> BikeEndTime (set @DropEvenIfDisagree = 1 to accept)');
    END;
END;

-- Check 2: anything in dbo that still uses the old columns
DECLARE @Users nvarchar(2000) = STUFF((
    SELECT DISTINCT N', ' + OBJECT_SCHEMA_NAME(mo.object_id) + N'.' + OBJECT_NAME(mo.object_id)
    FROM sys.sql_modules AS mo
    JOIN sys.objects AS o ON o.object_id = mo.object_id
    WHERE o.schema_id = SCHEMA_ID(N'dbo')
      AND EXISTS (SELECT 1 FROM sys.sql_expression_dependencies AS d
                  WHERE d.referencing_id = mo.object_id AND d.referenced_entity_name = N'RecreationalRide'
                    AND ISNULL(d.referenced_schema_name, N'dbo') = N'dbo')
      AND (mo.definition LIKE N'%RideTimeHours%' OR mo.definition LIKE N'%RideTimeMinutes%' OR mo.definition LIKE N'%RideTimeSeconds%' OR mo.definition LIKE N'%BikeTimeHours%' OR mo.definition LIKE N'%BikeTimeMinutes%' OR mo.definition LIKE N'%BikeTimeSeconds%')
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Users IS NOT NULL
    SET @Problems += NCHAR(10) + N'   still used in dbo by ' + @Users + N' (update the views and archive the procedures first)';

-- Check 4: rows the new table's constraints would reject (some foreign keys were never checked on old rows)
SELECT @n = COUNT(*) FROM dbo.RecreationalRide AS t WHERE t.BikeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Bike AS p WHERE p.Id = t.BikeId);
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break FK_RecreationalRide_Bike (BikeId has no matching dbo.Bike row)');
SELECT @n = COUNT(*) FROM dbo.RecreationalRide AS t WHERE t.GpxJsonId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.GpxJson AS p WHERE p.Id = t.GpxJsonId);
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break FK_RecreationalRide_GpxJson (GpxJsonId has no matching dbo.GpxJson row)');
SELECT @n = COUNT(*) FROM dbo.RecreationalRide AS t WHERE t.RouteId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Route AS p WHERE p.Id = t.RouteId);
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break FK_RecreationalRide_Route (RouteId has no matching dbo.Route row)');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (AverageCadence>(0) AND AverageCadence<(200));', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_AverageRecCadence: AverageCadence>(0) AND AverageCadence<(200)');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (AverageHR>(0) AND AverageHR<(220));', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_AverageRecHR: AverageHR>(0) AND AverageHR<(220)');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (EndOdometer>(0));', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_EndRecOdometer: EndOdometer>(0)');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (MaxHR>(0) AND MaxHR<(220));', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_MaxRecHR: MaxHR>(0) AND MaxHR<(220)');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (EndOdometer>StartOdometer);', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_RideRecMiles: EndOdometer>StartOdometer');
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE NOT (StartOdometer>(0));', N'@n int OUTPUT', @n = @n OUTPUT;
IF @n > 0 SET @Problems += CONCAT(NCHAR(10), N'   ', @n, N' row(s) break CK_StartRecOdometer: StartOdometer>(0)');

-- Check 5: columns or triggers on the live table that tables/RecreationalRide.sql doesn't have, and indexes that can't be carried over
DECLARE @Extra nvarchar(2000) = STUFF((
    SELECT N', ' + name FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.RecreationalRide') AND name NOT IN (N'Id', N'Date', N'StartOdometer', N'EndOdometer', N'Distance', N'StartTime', N'EndTime', N'RideTimeHours', N'RideTimeMinutes', N'RideTimeSeconds', N'BikeEndTime', N'BikeTimeHours', N'BikeTimeMinutes', N'BikeTimeSeconds', N'AverageHR', N'MaxHR', N'AverageCadence', N'ElevationGain', N'MaxSpeed', N'Wind', N'Temperature', N'Precipitation', N'BikeId', N'RouteId', N'GpxJsonId', N'Notes') AND name NOT IN (N'Duration', N'BikeDuration', N'RestDuration')
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Extra IS NOT NULL
    SET @Problems += NCHAR(10) + N'   columns not in tables/RecreationalRide.sql (they would be lost): ' + @Extra;
SET @Extra = STUFF((
    SELECT DISTINCT N', ' + i.name FROM sys.indexes AS i
    JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    WHERE i.object_id = OBJECT_ID(N'dbo.RecreationalRide') AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
      AND COL_NAME(ic.object_id, ic.column_id) IN (N'RideTimeHours', N'RideTimeMinutes', N'RideTimeSeconds', N'BikeTimeHours', N'BikeTimeMinutes', N'BikeTimeSeconds')
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Extra IS NOT NULL
    SET @Problems += NCHAR(10) + N'   indexes that use the old duration columns (drop them first): ' + @Extra;
SET @Extra = STUFF((
    SELECT N', ' + name + N' (' + type_desc + N')' FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.RecreationalRide') AND index_id > 0 AND is_primary_key = 0 AND is_unique_constraint = 0
      AND type <> 2
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Extra IS NOT NULL
    SET @Problems += NCHAR(10) + N'   index types this script cannot carry over (only nonclustered rowstore): ' + @Extra;

-- Indexes on the live table that tables/RecreationalRide.sql doesn't list: recreated after the copy, exactly as they are now
DECLARE @Indexes TABLE (Name sysname, CreateSql nvarchar(max));
INSERT @Indexes (Name, CreateSql)
SELECT i.name,
       N'CREATE ' + CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END + N'NONCLUSTERED INDEX ' + QUOTENAME(i.name)
       + N' ON dbo.RecreationalRide ('
       + STUFF((SELECT N', ' + QUOTENAME(c.name) + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N'' END
                FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0 AND ic.key_ordinal > 0
                ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'')
       + N')'
       + ISNULL(N' INCLUDE (' + STUFF((SELECT N', ' + QUOTENAME(c.name)
                FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                ORDER BY ic.index_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') + N')', N'')
       + CASE WHEN i.has_filter = 1 THEN N' WHERE ' + i.filter_definition ELSE N'' END
       + CASE WHEN i.fill_factor > 0 THEN N' WITH (FILLFACTOR = ' + CONVERT(nvarchar(3), i.fill_factor) + N')' ELSE N'' END
       + N';'
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID(N'dbo.RecreationalRide') AND i.type = 2 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0;
IF EXISTS (SELECT 1 FROM @Indexes)
BEGIN
    PRINT N'Indexes that will be recreated on the new table:';
    DECLARE ix CURSOR LOCAL FAST_FORWARD FOR SELECT CreateSql FROM @Indexes;
    OPEN ix; FETCH NEXT FROM ix INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN PRINT N'   ' + @sql; FETCH NEXT FROM ix INTO @sql; END;
    CLOSE ix; DEALLOCATE ix;
END;
SET @Extra = STUFF((
    SELECT N', ' + name FROM sys.triggers WHERE parent_id = OBJECT_ID(N'dbo.RecreationalRide')
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Extra IS NOT NULL
    SET @Problems += NCHAR(10) + N'   triggers on the table (they would be lost): ' + @Extra;

-- Check 3: leftover from an earlier run
IF OBJECT_ID(N'dbo.RecreationalRide_Old', N'U') IS NOT NULL
    SET @Problems += NCHAR(10) + N'   dbo.RecreationalRide_Old already exists (left by an earlier run); check it and drop or rename it';

IF @Problems <> N''
BEGIN
    PRINT N'Problems (nothing was changed):' + @Problems;
    RAISERROR(N'Fix the problems listed above and run again. Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @RowCount bigint = (SELECT SUM(row_count) FROM sys.dm_db_partition_stats
                            WHERE object_id = OBJECT_ID(N'dbo.RecreationalRide') AND index_id IN (0, 1));
PRINT CONCAT(N'Rows to copy: ', @RowCount);
IF @Apply = 0
BEGIN
    PRINT N'Checks passed. Set @Apply = 1 to rebuild dbo.RecreationalRide.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Foreign keys in other tables that reference dbo.RecreationalRide: record, then drop
    DECLARE @Refs TABLE (DropSql nvarchar(max), AddSql nvarchar(max));
    INSERT @Refs (DropSql, AddSql)
    SELECT N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
           + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';',
           N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
           + CASE WHEN fk.is_not_trusted = 1 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END
           + N' ADD CONSTRAINT ' + QUOTENAME(fk.name) + N' FOREIGN KEY ('
           + STUFF((SELECT N', ' + QUOTENAME(COL_NAME(fkc.parent_object_id, fkc.parent_column_id))
                    FROM sys.foreign_key_columns fkc WHERE fkc.constraint_object_id = fk.object_id
                    ORDER BY fkc.constraint_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'')
           + N') REFERENCES dbo.RecreationalRide ('
           + STUFF((SELECT N', ' + QUOTENAME(COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id))
                    FROM sys.foreign_key_columns fkc WHERE fkc.constraint_object_id = fk.object_id
                    ORDER BY fkc.constraint_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'')
           + N')'
           + CASE fk.delete_referential_action WHEN 1 THEN N' ON DELETE CASCADE' WHEN 2 THEN N' ON DELETE SET NULL'
                                               WHEN 3 THEN N' ON DELETE SET DEFAULT' ELSE N'' END
           + CASE fk.update_referential_action WHEN 1 THEN N' ON UPDATE CASCADE' WHEN 2 THEN N' ON UPDATE SET NULL'
                                               WHEN 3 THEN N' ON UPDATE SET DEFAULT' ELSE N'' END
           + CASE WHEN fk.is_disabled = 1 THEN N'; ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.'
                       + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' NOCHECK CONSTRAINT ' + QUOTENAME(fk.name) ELSE N'' END
           + N';'
    FROM sys.foreign_keys AS fk
    WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.RecreationalRide') AND fk.parent_object_id <> fk.referenced_object_id;

    DECLARE r CURSOR LOCAL FAST_FORWARD FOR SELECT DropSql FROM @Refs;
    OPEN r; FETCH NEXT FROM r INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_executesql @sql; FETCH NEXT FROM r INTO @sql; END;
    CLOSE r; DEALLOCATE r;

    -- 2. Rename the table and its constraints out of the way
    DECLARE @LastId numeric(38, 0) = IDENT_CURRENT(N'dbo.RecreationalRide');
    EXEC sp_rename N'dbo.RecreationalRide', N'RecreationalRide_Old', N'OBJECT';
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'dbo.' + QUOTENAME(name), name + N'_Old' FROM sys.objects
        WHERE parent_object_id = OBJECT_ID(N'dbo.RecreationalRide_Old') AND type IN ('PK', 'UQ', 'F', 'C', 'D');
    DECLARE @old nvarchar(300), @new sysname;
    OPEN c; FETCH NEXT FROM c INTO @old, @new;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_rename @old, @new, N'OBJECT'; FETCH NEXT FROM c INTO @old, @new; END;
    CLOSE c; DEALLOCATE c;

    -- 3. Create the table in the new layout
    EXEC (N'CREATE TABLE dbo.RecreationalRide
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           datetime       NOT NULL,
    StartOdometer    int            NOT NULL,
    EndOdometer      int            NOT NULL,
    Distance         decimal(9, 4)  NULL,
    StartTime        datetime       NOT NULL,
    EndTime          datetime       NOT NULL,
    Duration         AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, EndTime) / 3600 < 10 THEN ''0'' ELSE '''' END,
                               DATEDIFF(second, StartTime, EndTime) / 3600, '':'',
                               RIGHT(CONCAT(''0'', DATEDIFF(second, StartTime, EndTime) % 3600 / 60), 2), '':'',
                               RIGHT(CONCAT(''0'', DATEDIFF(second, StartTime, EndTime) % 60), 2)),
    BikeEndTime      datetime       NOT NULL,
    BikeDuration     AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, BikeEndTime) / 3600 < 10 THEN ''0'' ELSE '''' END,
                               DATEDIFF(second, StartTime, BikeEndTime) / 3600, '':'',
                               RIGHT(CONCAT(''0'', DATEDIFF(second, StartTime, BikeEndTime) % 3600 / 60), 2), '':'',
                               RIGHT(CONCAT(''0'', DATEDIFF(second, StartTime, BikeEndTime) % 60), 2)),
    RestDuration     AS CONCAT(CASE WHEN DATEDIFF(second, BikeEndTime, EndTime) < 0 THEN ''-'' ELSE '''' END,
                               CASE WHEN ABS(DATEDIFF(second, BikeEndTime, EndTime)) / 3600 < 10 THEN ''0'' ELSE '''' END, ABS(DATEDIFF(second, BikeEndTime, EndTime)) / 3600, '':'',
                               RIGHT(CONCAT(''0'', ABS(DATEDIFF(second, BikeEndTime, EndTime)) % 3600 / 60), 2), '':'',
                               RIGHT(CONCAT(''0'', ABS(DATEDIFF(second, BikeEndTime, EndTime)) % 60), 2)),
    AverageHR        int            NOT NULL,
    MaxHR            int            NOT NULL,
    AverageCadence   int            NOT NULL,
    ElevationGain    int            NOT NULL,
    MaxSpeed         decimal(9, 4)  NOT NULL,
    Wind             nvarchar(255)  NOT NULL,
    Temperature      int            NOT NULL,
    Precipitation    bit            NOT NULL,
    BikeId           int            NOT NULL,
    RouteId          int            NOT NULL,
    GpxJsonId        int            NULL,
    Notes            nvarchar(4000) NULL,

    CONSTRAINT PK_RecreationalRide PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_RecreationalRide_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id),
    CONSTRAINT FK_RecreationalRide_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_RecreationalRide_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT CK_AverageRecCadence CHECK (AverageCadence>(0) AND AverageCadence<(200)),
    CONSTRAINT CK_AverageRecHR CHECK (AverageHR>(0) AND AverageHR<(220)),
    CONSTRAINT CK_EndRecOdometer CHECK (EndOdometer>(0)),
    CONSTRAINT CK_MaxRecHR CHECK (MaxHR>(0) AND MaxHR<(220)),
    CONSTRAINT CK_RideRecMiles CHECK (EndOdometer>StartOdometer),
    CONSTRAINT CK_StartRecOdometer CHECK (StartOdometer>(0))
);');

    -- 4. Copy the rows, keep the identity seed, drop the old table
    EXEC (N'SET IDENTITY_INSERT dbo.RecreationalRide ON;
INSERT INTO dbo.RecreationalRide ([Id], [Date], [StartOdometer], [EndOdometer], [Distance], [StartTime], [EndTime], [BikeEndTime], [AverageHR], [MaxHR], [AverageCadence], [ElevationGain], [MaxSpeed], [Wind], [Temperature], [Precipitation], [BikeId], [RouteId], [GpxJsonId], [Notes])
SELECT [Id], [Date], [StartOdometer], [EndOdometer], [Distance], [StartTime], [EndTime], [BikeEndTime], [AverageHR], [MaxHR], [AverageCadence], [ElevationGain], [MaxSpeed], [Wind], [Temperature], [Precipitation], [BikeId], [RouteId], [GpxJsonId], [Notes]
FROM dbo.RecreationalRide_Old;
SET IDENTITY_INSERT dbo.RecreationalRide OFF;');
    IF @LastId > ISNULL(IDENT_CURRENT(N'dbo.RecreationalRide'), 0)
    BEGIN
        SET @sql = N'DBCC CHECKIDENT (N''dbo.RecreationalRide'', RESEED, ' + CONVERT(nvarchar(40), @LastId) + N') WITH NO_INFOMSGS;';
        EXEC sp_executesql @sql;
    END;
    IF (SELECT COUNT_BIG(*) FROM dbo.RecreationalRide) <> (SELECT COUNT_BIG(*) FROM dbo.RecreationalRide_Old)
        THROW 50030, N'Row counts differ after the copy. Rolled back.', 1;
    DROP TABLE dbo.RecreationalRide_Old;

    DECLARE ixa CURSOR LOCAL FAST_FORWARD FOR SELECT CreateSql FROM @Indexes;
    OPEN ixa; FETCH NEXT FROM ixa INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_executesql @sql; FETCH NEXT FROM ixa INTO @sql; END;
    CLOSE ixa; DEALLOCATE ixa;

    -- 5. Recreate the referencing foreign keys, refresh dependent views
    DECLARE a CURSOR LOCAL FAST_FORWARD FOR SELECT AddSql FROM @Refs;
    OPEN a; FETCH NEXT FROM a INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_executesql @sql; FETCH NEXT FROM a INTO @sql; END;
    CLOSE a; DEALLOCATE a;

    DECLARE v CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id)) + N'.' + QUOTENAME(OBJECT_NAME(d.referencing_id))
        FROM sys.sql_expression_dependencies AS d
        JOIN sys.views AS vw ON vw.object_id = d.referencing_id
        WHERE d.referenced_id = OBJECT_ID(N'dbo.RecreationalRide')
           OR (d.referenced_entity_name = N'RecreationalRide' AND ISNULL(d.referenced_schema_name, N'dbo') = N'dbo');
    OPEN v; FETCH NEXT FROM v INTO @old;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_refreshview @old; FETCH NEXT FROM v INTO @old; END;
    CLOSE v; DEALLOCATE v;

    COMMIT;
    PRINT N'dbo.RecreationalRide rebuilt: Duration after EndTime, BikeDuration after BikeEndTime, RestDuration after BikeDuration; old duration columns removed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
