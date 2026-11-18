-- S14_rename_objects.sql
-- S14: renames primary keys, foreign keys, check constraints and unique indexes to one convention:
--   PK_<Table>, FK_<Table>_<ReferencedTable>, CK_<Table>_<Rule>, UQ_<Table>_<Columns>.
-- 39 renames, starting with the system-generated PK__BikeOnlyMiles__4885B9BB (its name differs on every server).
-- Renaming changes no data, no column and no behaviour. Tables keep their names (CircuitsComponents, Weight): renaming a
-- table would break the API. Defaults (DF_<Table>_<Column>) already follow the convention.
-- The SQL project table files and tables/*.sql use the new names, so after this a DeployReport shows no differences.
--
-- Safe to re-run: a rename already done is skipped. In production, run it after the Duration rebuild (the rebuild
-- scripts already create TrainingRide, RecreationalRide, RecreationalWalk and TreadmillRun with the new names).
-- API: nothing at run time. If the EF model was scaffolded, its HasName / HasConstraintName / HasDatabaseName calls
-- still show the old names; re-scaffold or edit them so a future migration doesn't rename them back.
--
-- @Apply = 0 lists each rename and its state; @Apply = 1 renames, in one transaction.
-- sp_rename prints "Caution: Changing any part of an object name..." once per rename; that is expected.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S14_rename_objects.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = rename

DECLARE @Map TABLE (Seq int IDENTITY PRIMARY KEY, Kind nchar(1), TableName sysname, OldName sysname, NewName sysname,
                    OldExists bit, NewExists bit, State nvarchar(20));
INSERT @Map (Kind, TableName, OldName, NewName) VALUES
    (N'O', N'BikeOnlyMiles', N'PK__BikeOnlyMiles__4885B9BB', N'PK_BikeOnlyMiles'),
    (N'O', N'LiftingSession', N'PK_LiftSession', N'PK_LiftingSession'),
    (N'O', N'NonRideMiles', N'PK_NonBikeMiles', N'PK_NonRideMiles'),
    (N'O', N'RouteDisplay', N'PK_RouteDescriptionDisplay', N'PK_RouteDisplay'),
    (N'O', N'RouteDirection', N'PK_RouteDirections', N'PK_RouteDirection'),
    (N'O', N'TreadmillRun', N'PK_Treadmill', N'PK_TreadmillRun'),
    (N'O', N'HRZoneTime', N'FK_HRZoneTime_TrainingRides', N'FK_HRZoneTime_TrainingRide'),
    (N'O', N'LiftingSession', N'FK_LiftSession_Circuit', N'FK_LiftingSession_Circuit'),
    (N'O', N'RecreationalWalk', N'FK_RecreationalWalk_GpxJsonId', N'FK_RecreationalWalk_GpxJson'),
    (N'O', N'Route', N'FK_Route_Type', N'FK_Route_RouteType'),
    (N'O', N'RouteDisplay', N'FK_RouteDescriptionDisplay_Route', N'FK_RouteDisplay_Route'),
    (N'O', N'TrainingRide', N'CK_AverageCadence', N'CK_TrainingRide_AverageCadence'),
    (N'O', N'TrainingRide', N'CK_AverageHR', N'CK_TrainingRide_AverageHR'),
    (N'O', N'TrainingRide', N'CK_EndOdometer', N'CK_TrainingRide_EndOdometer'),
    (N'O', N'TrainingRide', N'CK_MaxHR', N'CK_TrainingRide_MaxHR'),
    (N'O', N'TrainingRide', N'CK_RideMiles', N'CK_TrainingRide_Miles'),
    (N'O', N'TrainingRide', N'CK_StartOdometer', N'CK_TrainingRide_StartOdometer'),
    (N'O', N'TrainingRide', N'CK_WindSpeed', N'CK_TrainingRide_WindSpeed'),
    (N'O', N'RecreationalRide', N'CK_AverageRecCadence', N'CK_RecreationalRide_AverageCadence'),
    (N'O', N'RecreationalRide', N'CK_AverageRecHR', N'CK_RecreationalRide_AverageHR'),
    (N'O', N'RecreationalRide', N'CK_EndRecOdometer', N'CK_RecreationalRide_EndOdometer'),
    (N'O', N'RecreationalRide', N'CK_MaxRecHR', N'CK_RecreationalRide_MaxHR'),
    (N'O', N'RecreationalRide', N'CK_RideRecMiles', N'CK_RecreationalRide_Miles'),
    (N'O', N'RecreationalRide', N'CK_StartRecOdometer', N'CK_RecreationalRide_StartOdometer'),
    (N'I', N'Bike', N'UNIQUE_Bike_Name', N'UQ_Bike_Name'),
    (N'I', N'BikePart', N'UNIQUE_BikePart', N'UQ_BikePart_BikeId_PartId_OdometerReading'),
    (N'I', N'BikeType', N'UNIQUE_EnumId', N'UQ_BikeType_EnumId'),
    (N'I', N'Circuit', N'UNIQUE_Name', N'UQ_Circuit_Name'),
    (N'I', N'CircuitComponent', N'UNIQUE_ExerciseName', N'UQ_CircuitComponent_ExerciseName'),
    (N'I', N'CircuitsComponents', N'UNIQUE_CircuitId_CircuitComponentId', N'UQ_CircuitsComponents_CircuitId_CircuitComponentId'),
    (N'I', N'Maintenance', N'UNIQUE_Maintenance', N'UQ_Maintenance_BikeId_PartId_ActionTaken_Odometer'),
    (N'I', N'Manufacturer', N'UNIQUE_Manufacturer_Name', N'UQ_Manufacturer_Name'),
    (N'I', N'Part', N'UNIQUE_Part', N'UQ_Part_ManufacturerId_PartTypeId_Name'),
    (N'I', N'PartType', N'UNIQUE_PartType_Name', N'UQ_PartType_Name'),
    (N'I', N'Route', N'UNIQUE_Route_Name', N'UQ_Route_Name'),
    (N'I', N'RouteDirection', N'UNIQUE_Route_Id_Number', N'UQ_RouteDirection_RouteId_DirectionNumber'),
    (N'I', N'RouteDisplay', N'UNIQUE_RouteId', N'UQ_RouteDisplay_RouteId'),
    (N'I', N'RouteType', N'UNIQUE_EnumId', N'UQ_RouteType_EnumId'),
    (N'I', N'Weight', N'UNIQUE_Date', N'UQ_Weight_Date');

UPDATE m SET
    OldExists = CASE WHEN m.Kind = N'O'
                     THEN CASE WHEN EXISTS (SELECT 1 FROM sys.objects o WHERE o.name = m.OldName AND o.schema_id = SCHEMA_ID(N'dbo')
                                             AND o.parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(m.TableName))) THEN 1 ELSE 0 END
                     ELSE CASE WHEN EXISTS (SELECT 1 FROM sys.indexes i WHERE i.name = m.OldName
                                             AND i.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(m.TableName))) THEN 1 ELSE 0 END END,
    NewExists = CASE WHEN m.Kind = N'O'
                     THEN CASE WHEN EXISTS (SELECT 1 FROM sys.objects o WHERE o.name = m.NewName AND o.schema_id = SCHEMA_ID(N'dbo')) THEN 1 ELSE 0 END
                     ELSE CASE WHEN EXISTS (SELECT 1 FROM sys.indexes i WHERE i.name = m.NewName
                                             AND i.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(m.TableName))) THEN 1 ELSE 0 END END
FROM @Map AS m;

UPDATE @Map SET State = CASE WHEN OldExists = 1 AND NewExists = 0 THEN N'to rename'
                             WHEN OldExists = 0 AND NewExists = 1 THEN N'already done'
                             WHEN OldExists = 1 AND NewExists = 1 THEN N'CONFLICT'
                             ELSE N'NOT FOUND' END;

SELECT TableName, OldName, NewName, State FROM @Map ORDER BY Seq;
SELECT State, COUNT(*) AS Renames FROM @Map GROUP BY State ORDER BY State;
DECLARE @Count int = (SELECT COUNT(*) FROM @Map WHERE State = N'to rename');

IF EXISTS (SELECT 1 FROM @Map WHERE State IN (N'CONFLICT', N'NOT FOUND'))
BEGIN
    RAISERROR(N'Some names are in an unexpected state (CONFLICT or NOT FOUND above). Nothing was changed.', 16, 1);
    RETURN;
END;

IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count,
                 N' rename(s) to do; set @Apply = 1 to rename.');
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @k nchar(1), @t sysname, @o sysname, @n sysname, @obj nvarchar(600);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Kind, TableName, OldName, NewName FROM @Map WHERE State = N'to rename' ORDER BY Seq;
    OPEN c; FETCH NEXT FROM c INTO @k, @t, @o, @n;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @k = N'O'
        BEGIN
            SET @obj = N'dbo.' + QUOTENAME(@o);
            EXEC sys.sp_rename @objname = @obj, @newname = @n, @objtype = N'OBJECT';
        END
        ELSE
        BEGIN
            SET @obj = N'dbo.' + QUOTENAME(@t) + N'.' + QUOTENAME(@o);
            EXEC sys.sp_rename @objname = @obj, @newname = @n, @objtype = N'INDEX';
        END;
        FETCH NEXT FROM c INTO @k, @t, @o, @n;
    END;
    CLOSE c; DEALLOCATE c;
    COMMIT;
    PRINT CONCAT(N'Renamed ', @Count, N' object(s).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
