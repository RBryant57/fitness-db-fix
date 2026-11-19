-- S7_check_constraints.sql
-- S7: one consistent set of sanity checks on the nine activity tables (58 checks). Only checks a table doesn't have
-- yet are added; the existing ride checks (TrainingRide, RecreationalRide) are kept as they are.
--   * Times: EndTime after StartTime (also stops a zero-length row from making the report views divide by zero, V2).
--   * Heart rate: AverageHR and MaxHR 0-250 (0 = not recorded), MaxHR >= AverageHR.
--   * Distance > 0 (rides: NULL or > 0), ElevationGain >= 0, Temperature -60 to 140, WindSpeed >= 0,
--     StationaryRide cadence 0-250, Stairs StairQuantity > 0.
-- Every check is added WITH CHECK (trusted). On the staging data of 2026-11-16 no row breaks any of them.
-- The SQL project and the rebuild scripts include these checks, so a production rebuild creates them directly
-- and this script then skips them.
-- API: an insert or update that breaks a check now fails with Msg 547 (CHECK constraint conflict) instead of saving.
--
-- @Apply = 0 lists each check with the rows that break it; @Apply = 1 adds them (stops if any row breaks one).
-- sqlcmd -S <server> -d Fitness -E -I -b -i S7_check_constraints.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = add

DECLARE @C TABLE (Seq int IDENTITY PRIMARY KEY, TableName sysname, Name sysname, Definition nvarchar(400), Breaking int NULL, State nvarchar(20) NULL);
INSERT @C (TableName, Name, Definition) VALUES
    (N'TrainingRide', N'CK_TrainingRide_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'TrainingRide', N'CK_TrainingRide_Times', N'([EndTime]>[StartTime])'),
    (N'TrainingRide', N'CK_TrainingRide_Distance', N'([Distance] IS NULL OR [Distance]>(0))'),
    (N'TrainingRide', N'CK_TrainingRide_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'TrainingRide', N'CK_TrainingRide_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))'),
    (N'TrainingRun', N'CK_TrainingRun_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'TrainingRun', N'CK_TrainingRun_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'TrainingRun', N'CK_TrainingRun_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'TrainingRun', N'CK_TrainingRun_Times', N'([EndTime]>[StartTime])'),
    (N'TrainingRun', N'CK_TrainingRun_Distance', N'([Distance]>(0))'),
    (N'TrainingRun', N'CK_TrainingRun_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'TrainingRun', N'CK_TrainingRun_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))'),
    (N'TrainingRun', N'CK_TrainingRun_WindSpeed', N'([WindSpeed]>=(0))'),
    (N'TrainingWalk', N'CK_TrainingWalk_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'TrainingWalk', N'CK_TrainingWalk_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'TrainingWalk', N'CK_TrainingWalk_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'TrainingWalk', N'CK_TrainingWalk_Times', N'([EndTime]>[StartTime])'),
    (N'TrainingWalk', N'CK_TrainingWalk_Distance', N'([Distance]>(0))'),
    (N'TrainingWalk', N'CK_TrainingWalk_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'TrainingWalk', N'CK_TrainingWalk_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))'),
    (N'TrainingWalk', N'CK_TrainingWalk_WindSpeed', N'([WindSpeed]>=(0))'),
    (N'TreadmillRun', N'CK_TreadmillRun_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'TreadmillRun', N'CK_TreadmillRun_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'TreadmillRun', N'CK_TreadmillRun_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'TreadmillRun', N'CK_TreadmillRun_Times', N'([EndTime]>[StartTime])'),
    (N'TreadmillRun', N'CK_TreadmillRun_Distance', N'([Distance]>(0))'),
    (N'TreadmillRun', N'CK_TreadmillRun_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'StationaryRide', N'CK_StationaryRide_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'StationaryRide', N'CK_StationaryRide_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'StationaryRide', N'CK_StationaryRide_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'StationaryRide', N'CK_StationaryRide_Times', N'([EndTime]>[StartTime])'),
    (N'StationaryRide', N'CK_StationaryRide_Distance', N'([Distance] IS NULL OR [Distance]>(0))'),
    (N'StationaryRide', N'CK_StationaryRide_AverageCadence', N'([AverageCadence]>=(0) AND [AverageCadence]<=(250))'),
    (N'Stairs', N'CK_Stairs_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'Stairs', N'CK_Stairs_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'Stairs', N'CK_Stairs_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'Stairs', N'CK_Stairs_Times', N'([EndTime]>[StartTime])'),
    (N'Stairs', N'CK_Stairs_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'Stairs', N'CK_Stairs_StairQuantity', N'([StairQuantity]>(0))'),
    (N'RecreationalRide', N'CK_RecreationalRide_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'RecreationalRide', N'CK_RecreationalRide_Times', N'([EndTime]>[StartTime])'),
    (N'RecreationalRide', N'CK_RecreationalRide_Distance', N'([Distance] IS NULL OR [Distance]>(0))'),
    (N'RecreationalRide', N'CK_RecreationalRide_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'RecreationalRide', N'CK_RecreationalRide_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))'),
    (N'RecreationalRun', N'CK_RecreationalRun_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'RecreationalRun', N'CK_RecreationalRun_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'RecreationalRun', N'CK_RecreationalRun_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'RecreationalRun', N'CK_RecreationalRun_Times', N'([EndTime]>[StartTime])'),
    (N'RecreationalRun', N'CK_RecreationalRun_Distance', N'([Distance]>(0))'),
    (N'RecreationalRun', N'CK_RecreationalRun_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'RecreationalRun', N'CK_RecreationalRun_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_AverageHR', N'([AverageHR]>=(0) AND [AverageHR]<=(250))'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_MaxHR', N'([MaxHR]>=(0) AND [MaxHR]<=(250))'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_MaxHRAboveAverage', N'([MaxHR]>=[AverageHR])'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_Times', N'([EndTime]>[StartTime])'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_Distance', N'([Distance]>(0))'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_ElevationGain', N'([ElevationGain]>=(0))'),
    (N'RecreationalWalk', N'CK_RecreationalWalk_Temperature', N'([Temperature]>=(-60) AND [Temperature]<=(140))');

UPDATE @C SET State = CASE WHEN OBJECT_ID(N'dbo.' + QUOTENAME(Name), N'C') IS NOT NULL THEN N'exists' ELSE N'to add' END;

DECLARE @seq int, @t sysname, @n sysname, @d nvarchar(400), @sql nvarchar(max), @cnt int;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Seq, TableName, Definition FROM @C WHERE State = N'to add';
OPEN c; FETCH NEXT FROM c INTO @seq, @t, @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'SELECT @cnt = COUNT(*) FROM dbo.' + QUOTENAME(@t) + N' WHERE NOT ' + @d + N';';
    EXEC sp_executesql @sql, N'@cnt int OUTPUT', @cnt = @cnt OUTPUT;
    UPDATE @C SET Breaking = @cnt, State = CASE WHEN @cnt > 0 THEN N'ROWS BREAK IT' ELSE State END WHERE Seq = @seq;
    FETCH NEXT FROM c INTO @seq, @t, @d;
END;
CLOSE c; DEALLOCATE c;

SELECT TableName, Name, Definition, Breaking, State FROM @C ORDER BY Seq;

IF EXISTS (SELECT 1 FROM @C WHERE State = N'ROWS BREAK IT')
BEGIN
    RAISERROR(N'Some rows break a check (see above). Fix the rows or leave that check out. Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @Count int = (SELECT COUNT(*) FROM @C WHERE State = N'to add');
IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count, N' check(s) to add; set @Apply = 1 to add them.');
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE a CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, Name, Definition FROM @C WHERE State = N'to add' ORDER BY Seq;
    OPEN a; FETCH NEXT FROM a INTO @t, @n, @d;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@n) + N' CHECK ' + @d + N';';
        EXEC sp_executesql @sql;
        FETCH NEXT FROM a INTO @t, @n, @d;
    END;
    CLOSE a; DEALLOCATE a;
    COMMIT;
    PRINT CONCAT(N'Added ', @Count, N' check(s).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
