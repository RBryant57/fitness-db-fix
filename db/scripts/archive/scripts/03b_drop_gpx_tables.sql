-- 03b_drop_gpx_tables.sql
-- Permanently drops the six legacy GPX tables from [archive], after the quarantine period.
--
-- Before running:
--   1. The API has run normally for the whole quarantine period with the tables archived.
--   2. Take a backup, and optionally export the original GPX (XML) documents. GpxJson holds the converted JSON, not
--      the original files, so this export is the only copy of the raw GPX after the drop. For example, per table:
--        bcp "SELECT * FROM Fitness.archive.TrainingRideGPX" queryout TrainingRideGPX.dat -S <server> -T -n
--   3. Run this script. It refuses to drop anything while a GPX row exists ONLY in these tables (its activity still
--      exists but has no GpxJsonId), unless you set @DropEvenIfOnlyCopy = 1 below.
--
-- sqlcmd -S <server> -d Fitness -E -I -b -i 03b_drop_gpx_tables.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'03b_drop_gpx_tables.sql must be run in the Fitness database. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

DECLARE @DropEvenIfOnlyCopy bit = 0;   -- set to 1 only if you have exported the rows reported below

DECLARE @Map TABLE (GpxTable sysname, ActivityTable sysname, FkColumn sysname);
INSERT @Map VALUES
    (N'TrainingRideGPX',     N'TrainingRide',     N'TrainingRideId'),
    (N'TrainingRunGPX',      N'TrainingRun',      N'TrainingRunId'),
    (N'TrainingWalkGPX',     N'TrainingWalk',     N'TrainingWalkId'),
    (N'RecreationalRideGPX', N'RecreationalRide', N'RecreationalRideId'),
    (N'RecreationalRunGPX',  N'RecreationalRun',  N'RecreationalRunId'),
    (N'RecreationalWalkGPX', N'RecreationalWalk', N'RecreationalWalkId');

DECLARE @Report TABLE (GpxTable sysname, GpxRows int, OnlyCopy int, ActivityDeleted int);
DECLARE @g sysname, @a sysname, @c sysname, @sql nvarchar(max);

DECLARE m CURSOR LOCAL FAST_FORWARD FOR SELECT GpxTable, ActivityTable, FkColumn FROM @Map;
OPEN m;
FETCH NEXT FROM m INTO @g, @a, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(N'archive.' + QUOTENAME(@g), N'U') IS NOT NULL
    BEGIN
        SET @sql = N'SELECT @t, COUNT(*),
                        SUM(CASE WHEN a.Id IS NOT NULL AND a.GpxJsonId IS NULL THEN 1 ELSE 0 END),
                        SUM(CASE WHEN a.Id IS NULL THEN 1 ELSE 0 END)
                     FROM archive.' + QUOTENAME(@g) + N' g
                     LEFT JOIN dbo.' + QUOTENAME(@a) + N' a ON a.Id = g.' + QUOTENAME(@c) + N';';
        INSERT @Report EXEC sp_executesql @sql, N'@t sysname', @t = @g;
    END;
    FETCH NEXT FROM m INTO @g, @a, @c;
END;
CLOSE m; DEALLOCATE m;

PRINT N'Archived GPX tables (OnlyCopy = activity exists but has no GpxJsonId; ActivityDeleted = activity no longer exists):';
SELECT GpxTable, GpxRows, OnlyCopy, ActivityDeleted FROM @Report ORDER BY GpxTable;

IF NOT EXISTS (SELECT 1 FROM @Report)
BEGIN
    PRINT N'No archived GPX tables found. Nothing to do.';
    RETURN;
END;

IF @DropEvenIfOnlyCopy = 0 AND EXISTS (SELECT 1 FROM @Report WHERE OnlyCopy > 0)
BEGIN
    RAISERROR(N'Some GPX rows exist only in the archived tables (see OnlyCopy). Export them or convert them to GpxJson, then set @DropEvenIfOnlyCopy = 1. Nothing was dropped.', 16, 1);
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS archive.TrainingRideGPX;
    DROP TABLE IF EXISTS archive.TrainingRunGPX;
    DROP TABLE IF EXISTS archive.TrainingWalkGPX;
    DROP TABLE IF EXISTS archive.RecreationalRideGPX;
    DROP TABLE IF EXISTS archive.RecreationalRunGPX;
    DROP TABLE IF EXISTS archive.RecreationalWalkGPX;

    DECLARE @Tables int = (SELECT COUNT(*) FROM @Report), @Rows int = (SELECT SUM(GpxRows) FROM @Report);
    IF OBJECT_ID(N'archive.ArchiveLog', N'U') IS NOT NULL
        INSERT archive.ArchiveLog (Note)
        VALUES (CONCAT(N'Dropped ', @Tables, N' legacy *GPX tables (', @Rows,
                       N' rows). Raw GPX kept only in any export taken beforehand.'));
    COMMIT;
    PRINT N'Legacy GPX tables dropped.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
