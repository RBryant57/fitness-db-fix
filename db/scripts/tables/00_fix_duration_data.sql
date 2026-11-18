-- 00_fix_duration_data.sql
-- Data corrections decided 2026-11-11, to run BEFORE the Duration rebuild (tables/rebuild_<Table>.sql).
-- Run on staging first, then production. Preview by default; set @Apply = 1 (or Run-FitnessScripts.ps1 -Phase DataFix -Apply).
--
--  1. Stored durations win. Where the stored hours/minutes/seconds disagree with the times, the end time is set to
--     StartTime + stored duration (EndTime, BikeEndTime or PathEndTime). Production 2026-10-31: 29 TrainingRide rows
--     (the 2003-05 rides with a placeholder 17:00 start, and ride 387, whose times said 1:42:07 for 20 miles), 3 StationaryRide
--     rows (seconds or less) and RecreationalRun 1's path time (10 seconds).
--  2. No negative rest. Where BikeEndTime / PathEndTime is after EndTime, EndTime is set to it (rest 0:00:00), and the stored
--     overall duration is updated to match so the rebuild's check passes. Production: RecreationalRun 1, RecreationalWalk 9.
--  3. Six 2023 TrainingWalk distances were the total of several walks (their GPS files were merged across days). They are
--     set to each day's GPS distance: 527 = 2.13, 531 = 2.16, 532 = 2.12, 533 = 4.23, 534 = 2.09, 535 = 2.20.
--     The merged GpxJson rows are not changed.
-- Re-runnable: each step only touches rows that still need it. After it, every rebuild preview should pass without
-- -DropEvenIfDisagree. Tables already rebuilt (no stored duration columns) are skipped.
-- sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i 00_fix_duration_data.sql
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list the rows that would change, 1 = change them

DECLARE @n int, @sql nvarchar(max), @Total int = 0;
IF @Apply = 1 BEGIN TRANSACTION;

PRINT N'== 1. End times from stored durations';
IF COL_LENGTH(N'dbo.TrainingRide', N'RideTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.TrainingRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.TrainingRide.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''TrainingRide'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds) AS SecondsLonger
                FROM dbo.TrainingRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.TrainingRide SET EndTime = DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.TrainingRun', N'RunTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.TrainingRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.TrainingRun.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''TrainingRun'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds) AS SecondsLonger
                FROM dbo.TrainingRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.TrainingRun SET EndTime = DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.TrainingWalk', N'WalkTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.TrainingWalk WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.TrainingWalk.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''TrainingWalk'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds) AS SecondsLonger
                FROM dbo.TrainingWalk WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.TrainingWalk SET EndTime = DATEADD(second, WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds, StartTime) WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.TreadmillRun', N'RunTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.TreadmillRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.TreadmillRun.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''TreadmillRun'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds) AS SecondsLonger
                FROM dbo.TreadmillRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.TreadmillRun SET EndTime = DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.StationaryRide', N'RideTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.StationaryRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.StationaryRide.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''StationaryRide'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds) AS SecondsLonger
                FROM dbo.StationaryRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.StationaryRide SET EndTime = DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.Stairs', N'StairTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.Stairs WHERE StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.Stairs.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''Stairs'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds) AS SecondsLonger
                FROM dbo.Stairs WHERE StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.Stairs SET EndTime = DATEADD(second, StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds, StartTime) WHERE StairTimeHours * 3600 + StairTimeMinutes * 60 + StairTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalRide', N'RideTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRide.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRide'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalRide WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRide SET EndTime = DATEADD(second, RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds, StartTime) WHERE RideTimeHours * 3600 + RideTimeMinutes * 60 + RideTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalRide', N'BikeTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds <> DATEDIFF(second, StartTime, BikeEndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRide.BikeEndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRide'' AS TableName, Id, [Date], StartTime, BikeEndTime AS CurrentEnd,
                       DATEADD(second, BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, BikeEndTime) - (BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalRide WHERE BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds <> DATEDIFF(second, StartTime, BikeEndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRide SET BikeEndTime = DATEADD(second, BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds, StartTime) WHERE BikeTimeHours * 3600 + BikeTimeMinutes * 60 + BikeTimeSeconds <> DATEDIFF(second, StartTime, BikeEndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalRun', N'RunTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRun.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRun'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalRun WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRun SET EndTime = DATEADD(second, RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds, StartTime) WHERE RunTimeHours * 3600 + RunTimeMinutes * 60 + RunTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalRun', N'PathTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRun WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRun.PathEndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRun'' AS TableName, Id, [Date], StartTime, PathEndTime AS CurrentEnd,
                       DATEADD(second, PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, PathEndTime) - (PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalRun WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRun SET PathEndTime = DATEADD(second, PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds, StartTime) WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalWalk', N'WalkTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalWalk WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalWalk.EndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalWalk'' AS TableName, Id, [Date], StartTime, EndTime AS CurrentEnd,
                       DATEADD(second, WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, EndTime) - (WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalWalk WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalWalk SET EndTime = DATEADD(second, WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds, StartTime) WHERE WalkTimeHours * 3600 + WalkTimeMinutes * 60 + WalkTimeSeconds <> DATEDIFF(second, StartTime, EndTime);');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalWalk', N'PathTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalWalk WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime);', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalWalk.PathEndTime: ', @n, N' row(s)');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalWalk'' AS TableName, Id, [Date], StartTime, PathEndTime AS CurrentEnd,
                       DATEADD(second, PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds, StartTime) AS NewEnd,
                       DATEDIFF(second, StartTime, PathEndTime) - (PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds) AS SecondsLonger
                FROM dbo.RecreationalWalk WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime) ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalWalk SET PathEndTime = DATEADD(second, PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds, StartTime) WHERE PathTimeHours * 3600 + PathTimeMinutes * 60 + PathTimeSeconds <> DATEDIFF(second, StartTime, PathEndTime);');
            SET @Total += @n;
        END;
    END;
END;

PRINT N'== 2. Rest time that would be negative';
IF COL_LENGTH(N'dbo.RecreationalRide', N'RideTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRide WHERE BikeEndTime > EndTime;', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRide: ', @n, N' row(s) where BikeEndTime is after EndTime');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRide'' AS TableName, Id, [Date], StartTime, BikeEndTime, EndTime AS CurrentEnd, BikeEndTime AS NewEnd
                FROM dbo.RecreationalRide WHERE BikeEndTime > EndTime ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRide
                    SET EndTime = BikeEndTime,
                        RideTimeHours   = DATEDIFF(second, StartTime, BikeEndTime) / 3600,
                        RideTimeMinutes = DATEDIFF(second, StartTime, BikeEndTime) % 3600 / 60,
                        RideTimeSeconds = DATEDIFF(second, StartTime, BikeEndTime) % 60
                    WHERE BikeEndTime > EndTime;');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalRun', N'RunTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalRun WHERE PathEndTime > EndTime;', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalRun: ', @n, N' row(s) where PathEndTime is after EndTime');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalRun'' AS TableName, Id, [Date], StartTime, PathEndTime, EndTime AS CurrentEnd, PathEndTime AS NewEnd
                FROM dbo.RecreationalRun WHERE PathEndTime > EndTime ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalRun
                    SET EndTime = PathEndTime,
                        RunTimeHours   = DATEDIFF(second, StartTime, PathEndTime) / 3600,
                        RunTimeMinutes = DATEDIFF(second, StartTime, PathEndTime) % 3600 / 60,
                        RunTimeSeconds = DATEDIFF(second, StartTime, PathEndTime) % 60
                    WHERE PathEndTime > EndTime;');
            SET @Total += @n;
        END;
    END;
END;
IF COL_LENGTH(N'dbo.RecreationalWalk', N'WalkTimeHours') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.RecreationalWalk WHERE PathEndTime > EndTime;', N'@n int OUTPUT', @n = @n OUTPUT;
    IF @n > 0
    BEGIN
        PRINT CONCAT(N'   dbo.RecreationalWalk: ', @n, N' row(s) where PathEndTime is after EndTime');
        IF @Apply = 0
            EXEC (N'SELECT ''RecreationalWalk'' AS TableName, Id, [Date], StartTime, PathEndTime, EndTime AS CurrentEnd, PathEndTime AS NewEnd
                FROM dbo.RecreationalWalk WHERE PathEndTime > EndTime ORDER BY [Date];');
        ELSE
        BEGIN
            EXEC (N'UPDATE dbo.RecreationalWalk
                    SET EndTime = PathEndTime,
                        WalkTimeHours   = DATEDIFF(second, StartTime, PathEndTime) / 3600,
                        WalkTimeMinutes = DATEDIFF(second, StartTime, PathEndTime) % 3600 / 60,
                        WalkTimeSeconds = DATEDIFF(second, StartTime, PathEndTime) % 60
                    WHERE PathEndTime > EndTime;');
            SET @Total += @n;
        END;
    END;
END;

PRINT N'== 3. TrainingWalk distances from the GPS track of each day';
DECLARE @Walks TABLE (Id int PRIMARY KEY, OldDistance decimal(9, 4), NewDistance decimal(9, 4));
INSERT @Walks VALUES (527, 10.57, 2.13), (531, 8.51, 2.16), (532, 8.51, 2.12), (533, 8.51, 4.23), (534, 4.3, 2.09), (535, 4.3, 2.20);
SELECT @n = COUNT(*) FROM dbo.TrainingWalk AS w JOIN @Walks AS x ON x.Id = w.Id AND w.Distance = x.OldDistance;
PRINT CONCAT(N'   ', @n, N' of 6 row(s) still have the merged distance');
IF @n > 0
BEGIN
    IF @Apply = 0
        SELECT w.Id, w.[Date], w.Distance AS CurrentDistance, x.NewDistance
        FROM dbo.TrainingWalk AS w JOIN @Walks AS x ON x.Id = w.Id AND w.Distance = x.OldDistance ORDER BY w.Id;
    ELSE
    BEGIN
        UPDATE w SET Distance = x.NewDistance
        FROM dbo.TrainingWalk AS w JOIN @Walks AS x ON x.Id = w.Id AND w.Distance = x.OldDistance;
        SET @Total += @n;
    END;
END;
IF EXISTS (SELECT 1 FROM dbo.TrainingWalk AS w JOIN @Walks AS x ON x.Id = w.Id AND w.Distance NOT IN (x.OldDistance, x.NewDistance))
    PRINT N'   Note: some of these walks have a distance that is neither the merged nor the GPS value; they were left alone.';

IF @Apply = 1
BEGIN
    COMMIT;
    PRINT CONCAT(N'Done: ', @Total, N' row change(s). Next: Run-FitnessScripts.ps1 -Phase Duration (preview).');
END
ELSE
    PRINT N'Preview only: nothing was changed. Run again with @Apply = 1 (Run-FitnessScripts.ps1 -Phase DataFix -Apply).';
GO

SET NOEXEC OFF;
GO
