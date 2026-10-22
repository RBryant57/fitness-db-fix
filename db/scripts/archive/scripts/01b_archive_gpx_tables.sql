-- 01b_archive_gpx_tables.sql
-- Archives the six legacy per-activity GPX tables, which GpxJson + GpxJsonId have replaced:
--   TrainingRideGPX, TrainingRunGPX, TrainingWalkGPX, RecreationalRideGPX, RecreationalRunGPX, RecreationalWalkGPX
--
-- What it does
--   Part 1 (read-only): reports row counts, how many GPX rows exist ONLY in these tables (their activity has no
--          GpxJsonId), and when the tables were last read or written since SQL Server started.
--   Part 2: stops if any object still in dbo references the tables (run 01_move_to_archive_schema.sql first).
--   Part 3: in one transaction, drops each table's foreign key to its activity table (so an archived table can never
--          block the API from deleting an activity) and moves the six tables, with their data, to the [archive]
--          schema. Logs the move in archive.ArchiveLog.
--
-- Nothing is deleted. Undo with 02b_rollback_gpx_archive.sql. Drop for good with 03b_drop_gpx_tables.sql after the
-- quarantine period. ALTER SCHEMA ... TRANSFER removes any permissions granted on the tables themselves, and the API's
-- roles have no rights on [archive], so nothing ordinary can read or write them once moved.
--
-- Run order: 00 -> 00c -> 00b -> 01 -> 01b. (00c writes test rows into TrainingRideGPX, so it must run before this.)
-- sqlcmd -S <server> -d Fitness -E -I -b -i 01b_archive_gpx_tables.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'01b_archive_gpx_tables.sql must be run in the Fitness database. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

------------------------------------------------------------------------------------------------------------------
-- Part 1: report (no changes)
------------------------------------------------------------------------------------------------------------------
DECLARE @Report TABLE (TableName sysname, GpxRows int, ActivityHasGpxJson int, OnlyCopyInThisTable int);

IF OBJECT_ID(N'dbo.TrainingRideGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''TrainingRideGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.TrainingRideGPX g LEFT JOIN dbo.TrainingRide a ON a.Id = g.TrainingRideId');
IF OBJECT_ID(N'dbo.TrainingRunGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''TrainingRunGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.TrainingRunGPX g LEFT JOIN dbo.TrainingRun a ON a.Id = g.TrainingRunId');
IF OBJECT_ID(N'dbo.TrainingWalkGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''TrainingWalkGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.TrainingWalkGPX g LEFT JOIN dbo.TrainingWalk a ON a.Id = g.TrainingWalkId');
IF OBJECT_ID(N'dbo.RecreationalRideGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''RecreationalRideGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.RecreationalRideGPX g LEFT JOIN dbo.RecreationalRide a ON a.Id = g.RecreationalRideId');
IF OBJECT_ID(N'dbo.RecreationalRunGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''RecreationalRunGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.RecreationalRunGPX g LEFT JOIN dbo.RecreationalRun a ON a.Id = g.RecreationalRunId');
IF OBJECT_ID(N'dbo.RecreationalWalkGPX', N'U') IS NOT NULL
    INSERT @Report EXEC (N'SELECT N''RecreationalWalkGPX'', COUNT(*), COUNT(a.GpxJsonId),
        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END)
        FROM dbo.RecreationalWalkGPX g LEFT JOIN dbo.RecreationalWalk a ON a.Id = g.RecreationalWalkId');

PRINT N'GPX tables still in dbo (OnlyCopyInThisTable = rows whose activity has no GpxJsonId; they are kept in the archive):';
SELECT TableName, GpxRows, ActivityHasGpxJson, OnlyCopyInThisTable FROM @Report ORDER BY TableName;

PRINT N'Use of the tables since SQL Server last started (a "Null value is eliminated" warning here is harmless):';
SELECT OBJECT_NAME(s.object_id) AS TableName,
       SUM(s.user_seeks + s.user_scans + s.user_lookups) AS Reads,
       SUM(s.user_updates) AS Writes,
       MAX(v.LastRead) AS LastRead,
       MAX(s.last_user_update) AS LastWrite,
       (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS SqlServerStarted
FROM sys.dm_db_index_usage_stats AS s
CROSS APPLY (SELECT MAX(x) FROM (VALUES (s.last_user_seek), (s.last_user_scan), (s.last_user_lookup)) AS r(x)
             WHERE x IS NOT NULL) AS v(LastRead)
WHERE s.database_id = DB_ID()
  AND s.object_id IN (OBJECT_ID(N'dbo.TrainingRideGPX'), OBJECT_ID(N'dbo.TrainingRunGPX'), OBJECT_ID(N'dbo.TrainingWalkGPX'),
                      OBJECT_ID(N'dbo.RecreationalRideGPX'), OBJECT_ID(N'dbo.RecreationalRunGPX'), OBJECT_ID(N'dbo.RecreationalWalkGPX'))
GROUP BY s.object_id;
GO

------------------------------------------------------------------------------------------------------------------
-- Part 2: stop if anything still in dbo depends on the tables
------------------------------------------------------------------------------------------------------------------
DECLARE @Blockers nvarchar(2000) =
    STUFF((SELECT DISTINCT N', ' + OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id)
           FROM sys.sql_expression_dependencies AS d
           JOIN sys.objects AS o ON o.object_id = d.referencing_id
           WHERE o.schema_id = SCHEMA_ID(N'dbo')
             AND ISNULL(d.referenced_schema_name, N'dbo') = N'dbo'
             AND d.referenced_entity_name IN (N'TrainingRideGPX', N'TrainingRunGPX', N'TrainingWalkGPX',
                                              N'RecreationalRideGPX', N'RecreationalRunGPX', N'RecreationalWalkGPX')
           FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');

IF @Blockers IS NOT NULL
BEGIN
    RAISERROR(N'These objects in dbo still reference the GPX tables: %s. Archive them first (01_move_to_archive_schema.sql moves all of them). Nothing was changed.', 16, 1, @Blockers);
    SET NOEXEC ON;
END;
GO

------------------------------------------------------------------------------------------------------------------
-- Part 3: archive
------------------------------------------------------------------------------------------------------------------
IF SCHEMA_ID(N'archive') IS NULL EXEC (N'CREATE SCHEMA archive AUTHORIZATION dbo');
GO
IF OBJECT_ID(N'archive.ArchiveLog', N'U') IS NULL
    CREATE TABLE archive.ArchiveLog (Id int IDENTITY PRIMARY KEY,
                                     ArchivedOn datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
                                     Note nvarchar(400) NOT NULL);
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Moved int = 0;

    IF OBJECT_ID(N'dbo.FK_TrainingRideGPX_TrainingRide', N'F') IS NOT NULL
        ALTER TABLE dbo.TrainingRideGPX DROP CONSTRAINT FK_TrainingRideGPX_TrainingRide;
    IF OBJECT_ID(N'dbo.TrainingRideGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.TrainingRideGPX; SET @Moved += 1; END;

    IF OBJECT_ID(N'dbo.FK_TrainingRunGPX_TrainingRun', N'F') IS NOT NULL
        ALTER TABLE dbo.TrainingRunGPX DROP CONSTRAINT FK_TrainingRunGPX_TrainingRun;
    IF OBJECT_ID(N'dbo.TrainingRunGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.TrainingRunGPX; SET @Moved += 1; END;

    IF OBJECT_ID(N'dbo.FK_TrainingWalkGPX_TrainingWalk', N'F') IS NOT NULL
        ALTER TABLE dbo.TrainingWalkGPX DROP CONSTRAINT FK_TrainingWalkGPX_TrainingWalk;
    IF OBJECT_ID(N'dbo.TrainingWalkGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.TrainingWalkGPX; SET @Moved += 1; END;

    IF OBJECT_ID(N'dbo.FK_RecreationalRideGPX_RecreationalRide', N'F') IS NOT NULL
        ALTER TABLE dbo.RecreationalRideGPX DROP CONSTRAINT FK_RecreationalRideGPX_RecreationalRide;
    IF OBJECT_ID(N'dbo.RecreationalRideGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.RecreationalRideGPX; SET @Moved += 1; END;

    IF OBJECT_ID(N'dbo.FK_RecreationalRunGPX_RecreationalRun', N'F') IS NOT NULL
        ALTER TABLE dbo.RecreationalRunGPX DROP CONSTRAINT FK_RecreationalRunGPX_RecreationalRun;
    IF OBJECT_ID(N'dbo.RecreationalRunGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.RecreationalRunGPX; SET @Moved += 1; END;

    IF OBJECT_ID(N'dbo.FK_RecreationalWalkGPX_RecreationalWalk', N'F') IS NOT NULL
        ALTER TABLE dbo.RecreationalWalkGPX DROP CONSTRAINT FK_RecreationalWalkGPX_RecreationalWalk;
    IF OBJECT_ID(N'dbo.RecreationalWalkGPX', N'U') IS NOT NULL
        BEGIN ALTER SCHEMA archive TRANSFER dbo.RecreationalWalkGPX; SET @Moved += 1; END;

    IF @Moved > 0
        INSERT archive.ArchiveLog (Note)
        VALUES (CONCAT(N'Moved ', @Moved, N' legacy *GPX tables (with data) from dbo to archive and dropped their ',
                       N'foreign keys to the activity tables. GpxJson + GpxJsonId is the live design.'));

    COMMIT;
    PRINT CONCAT(N'Archived ', @Moved, N' GPX table(s). Already archived or missing tables were skipped.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
