-- 02b_rollback_gpx_archive.sql
-- Undoes 01b_archive_gpx_tables.sql: moves the six legacy GPX tables from [archive] back to [dbo] and recreates
-- their foreign keys to the activity tables. The keys are recreated WITH NOCHECK, which is how they existed before
-- (the dacpac marks all six as not trusted). Any GPX rows whose activity was deleted while archived are listed.
-- Note: 02_rollback_archive.sql moves procedures and functions only; it does not move tables back.
-- sqlcmd -S <server> -d Fitness -E -I -b -i 02b_rollback_gpx_archive.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'02b_rollback_gpx_archive.sql must be run in the Fitness database. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Map TABLE (GpxTable sysname, ActivityTable sysname, FkColumn sysname, FkName sysname);
    INSERT @Map VALUES
        (N'TrainingRideGPX',     N'TrainingRide',     N'TrainingRideId',     N'FK_TrainingRideGPX_TrainingRide'),
        (N'TrainingRunGPX',      N'TrainingRun',      N'TrainingRunId',      N'FK_TrainingRunGPX_TrainingRun'),
        (N'TrainingWalkGPX',     N'TrainingWalk',     N'TrainingWalkId',     N'FK_TrainingWalkGPX_TrainingWalk'),
        (N'RecreationalRideGPX', N'RecreationalRide', N'RecreationalRideId', N'FK_RecreationalRideGPX_RecreationalRide'),
        (N'RecreationalRunGPX',  N'RecreationalRun',  N'RecreationalRunId',  N'FK_RecreationalRunGPX_RecreationalRun'),
        (N'RecreationalWalkGPX', N'RecreationalWalk', N'RecreationalWalkId', N'FK_RecreationalWalkGPX_RecreationalWalk');

    DECLARE @g sysname, @a sysname, @c sysname, @fk sysname, @sql nvarchar(max), @orphans int, @Restored int = 0;
    DECLARE m CURSOR LOCAL FAST_FORWARD FOR SELECT GpxTable, ActivityTable, FkColumn, FkName FROM @Map;
    OPEN m;
    FETCH NEXT FROM m INTO @g, @a, @c, @fk;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF OBJECT_ID(N'archive.' + QUOTENAME(@g), N'U') IS NOT NULL AND OBJECT_ID(N'dbo.' + QUOTENAME(@g), N'U') IS NULL
        BEGIN
            SET @sql = N'ALTER SCHEMA dbo TRANSFER archive.' + QUOTENAME(@g) + N';';
            EXEC sp_executesql @sql;
            SET @Restored += 1;
        END;

        IF OBJECT_ID(N'dbo.' + QUOTENAME(@g), N'U') IS NOT NULL AND OBJECT_ID(N'dbo.' + QUOTENAME(@fk), N'F') IS NULL
        BEGIN
            SET @sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@g) + N' g WHERE NOT EXISTS (SELECT 1 FROM dbo.'
                     + QUOTENAME(@a) + N' a WHERE a.Id = g.' + QUOTENAME(@c) + N');';
            EXEC sp_executesql @sql, N'@n int OUTPUT', @n = @orphans OUTPUT;
            IF @orphans > 0
                PRINT CONCAT(N'Warning: ', @orphans, N' row(s) in dbo.', @g, N' point to a deleted ', @a,
                             N'. The foreign key is recreated WITH NOCHECK, so these rows are kept.');

            SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@g) + N' WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME(@fk)
                     + N' FOREIGN KEY (' + QUOTENAME(@c) + N') REFERENCES dbo.' + QUOTENAME(@a) + N' (Id);';
            EXEC sp_executesql @sql;
        END;

        FETCH NEXT FROM m INTO @g, @a, @c, @fk;
    END;
    CLOSE m; DEALLOCATE m;

    IF @Restored > 0 AND OBJECT_ID(N'archive.ArchiveLog', N'U') IS NOT NULL
        INSERT archive.ArchiveLog (Note)
        VALUES (CONCAT(N'Rolled back: moved ', @Restored, N' legacy *GPX tables from archive to dbo and recreated their foreign keys.'));

    COMMIT;
    PRINT CONCAT(N'Moved ', @Restored, N' GPX table(s) back to dbo.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
