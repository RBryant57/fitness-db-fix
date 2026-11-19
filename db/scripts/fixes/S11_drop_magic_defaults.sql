-- S11_drop_magic_defaults.sql
-- S11: drops the defaults that silently point at a specific lookup row or record a made-up measurement when a caller
-- leaves the column out: ShoeId = 2 (TrainingRun, TrainingWalk), Route.TypeId = 1, and MaxSpeed = 20 / 8 / 3 on five
-- activity tables. After this an insert that leaves one of these columns out fails instead of storing a wrong value.
-- Kept: NumberOfAttempts / NumberOfSuccesses = 0 (a real default), Route.Rating = 5, MissedMiles.Date = today.
-- The SQL project and the rebuild scripts no longer have these defaults.
--
-- API, before applying: the API must always send ShoeId, TypeId and MaxSpeed. If the EF model was scaffolded, remove
-- the matching HasDefaultValue / HasDefaultValueSql calls; otherwise EF leaves a column out of the INSERT when the
-- property holds the CLR default (0), and the insert then fails.
--
-- @Apply = 0 lists the defaults; @Apply = 1 drops them. Safe to re-run.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S11_drop_magic_defaults.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = drop

DECLARE @D TABLE (Seq int IDENTITY PRIMARY KEY, TableName sysname, Name sysname, Definition nvarchar(400) NULL, State nvarchar(20) NULL);
INSERT @D (TableName, Name) VALUES
    (N'TrainingRun', N'DF_TrainingRun_ShoeId'),
    (N'TrainingWalk', N'DF_TrainingWalk_ShoeId'),
    (N'Route', N'DF_Route_TypeId'),
    (N'TrainingRide', N'DF_TrainingRide_MaxSpeed'),
    (N'TrainingRun', N'DF_TrainingRun_MaxSpeed'),
    (N'TrainingWalk', N'DF_TrainingWalk_MaxSpeed'),
    (N'RecreationalRun', N'DF_RecreationalRun_MaxSpeed'),
    (N'RecreationalWalk', N'DF_RecreationalWalk_MaxSpeed');

UPDATE d SET Definition = dc.definition,
             State = CASE WHEN dc.object_id IS NULL THEN N'already gone' ELSE N'to drop' END
FROM @D AS d
LEFT JOIN sys.default_constraints AS dc ON dc.name = d.Name AND dc.parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(d.TableName));

SELECT TableName, Name, Definition, State FROM @D ORDER BY Seq;

DECLARE @Count int = (SELECT COUNT(*) FROM @D WHERE State = N'to drop');
IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count, N' default(s) to drop; set @Apply = 1 to drop them.');
    RETURN;
END;

DECLARE @sql nvarchar(max);
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'ALTER TABLE dbo.' + QUOTENAME(TableName) + N' DROP CONSTRAINT ' + QUOTENAME(Name) + N';' FROM @D WHERE State = N'to drop' ORDER BY Seq;
    OPEN c; FETCH NEXT FROM c INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN PRINT @sql; EXEC sp_executesql @sql; FETCH NEXT FROM c INTO @sql; END;
    CLOSE c; DEALLOCATE c;
    COMMIT;
    PRINT CONCAT(N'Dropped ', @Count, N' default(s).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
