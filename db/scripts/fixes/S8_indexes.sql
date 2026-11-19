-- S8_indexes.sql
-- S8: nonclustered indexes on every foreign key column that isn't already the first column of an index (36), and on
-- [Date] in the nine activity tables and LiftingSession (10): 46 in all, named IX_<Table>_<Column>.
-- Joins on BikeId / RouteId / ShoeId / GpxJsonId ... and date-range queries no longer scan the whole table.
-- Small tables gain little today, but the cost is negligible and the plans stay good as the data grows.
-- No API change. The SQL project table files include these indexes. The table rebuild scripts carry nonclustered
-- indexes over, so the order relative to a rebuild doesn't matter.
--
-- @Apply = 0 lists them; @Apply = 1 creates the missing ones. Safe to re-run.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S8_indexes.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = create

DECLARE @I TABLE (Seq int IDENTITY PRIMARY KEY, TableName sysname, ColumnName sysname, Name sysname, State nvarchar(20) NULL);
INSERT @I (TableName, ColumnName, Name) VALUES
    (N'BenchmarkMiles', N'BikeId', N'IX_BenchmarkMiles_BikeId'),
    (N'Bike', N'TypeId', N'IX_Bike_TypeId'),
    (N'Bike', N'ManufacturerId', N'IX_Bike_ManufacturerId'),
    (N'BikeOnlyMiles', N'BikeId', N'IX_BikeOnlyMiles_BikeId'),
    (N'BikePart', N'PartId', N'IX_BikePart_PartId'),
    (N'CircuitsComponents', N'CircuitComponentId', N'IX_CircuitsComponents_CircuitComponentId'),
    (N'LiftingSession', N'CircuitId', N'IX_LiftingSession_CircuitId'),
    (N'Maintenance', N'PartId', N'IX_Maintenance_PartId'),
    (N'MissedMiles', N'ExerciseTypeId', N'IX_MissedMiles_ExerciseTypeId'),
    (N'NonRideMiles', N'BikeId', N'IX_NonRideMiles_BikeId'),
    (N'Part', N'PartTypeId', N'IX_Part_PartTypeId'),
    (N'RecreationalRide', N'BikeId', N'IX_RecreationalRide_BikeId'),
    (N'RecreationalRide', N'GpxJsonId', N'IX_RecreationalRide_GpxJsonId'),
    (N'RecreationalRide', N'RouteId', N'IX_RecreationalRide_RouteId'),
    (N'RecreationalRun', N'GpxJsonId', N'IX_RecreationalRun_GpxJsonId'),
    (N'RecreationalRun', N'RouteId', N'IX_RecreationalRun_RouteId'),
    (N'RecreationalRun', N'ShoeId', N'IX_RecreationalRun_ShoeId'),
    (N'RecreationalWalk', N'GpxJsonId', N'IX_RecreationalWalk_GpxJsonId'),
    (N'RecreationalWalk', N'RouteId', N'IX_RecreationalWalk_RouteId'),
    (N'RecreationalWalk', N'ShoeId', N'IX_RecreationalWalk_ShoeId'),
    (N'Route', N'TypeId', N'IX_Route_TypeId'),
    (N'RoutePicture', N'RouteId', N'IX_RoutePicture_RouteId'),
    (N'Shoe', N'ManufacturerId', N'IX_Shoe_ManufacturerId'),
    (N'Shoe', N'ShoeTypeId', N'IX_Shoe_ShoeTypeId'),
    (N'Stairs', N'ShoeId', N'IX_Stairs_ShoeId'),
    (N'StationaryRide', N'BikeId', N'IX_StationaryRide_BikeId'),
    (N'TrainingRide', N'BikeId', N'IX_TrainingRide_BikeId'),
    (N'TrainingRide', N'GpxJsonId', N'IX_TrainingRide_GpxJsonId'),
    (N'TrainingRide', N'RouteId', N'IX_TrainingRide_RouteId'),
    (N'TrainingRun', N'GpxJsonId', N'IX_TrainingRun_GpxJsonId'),
    (N'TrainingRun', N'RouteId', N'IX_TrainingRun_RouteId'),
    (N'TrainingRun', N'ShoeId', N'IX_TrainingRun_ShoeId'),
    (N'TrainingWalk', N'GpxJsonId', N'IX_TrainingWalk_GpxJsonId'),
    (N'TrainingWalk', N'RouteId', N'IX_TrainingWalk_RouteId'),
    (N'TrainingWalk', N'ShoeId', N'IX_TrainingWalk_ShoeId'),
    (N'TreadmillRun', N'ShoeId', N'IX_TreadmillRun_ShoeId'),
    (N'TrainingRide', N'Date', N'IX_TrainingRide_Date'),
    (N'TrainingRun', N'Date', N'IX_TrainingRun_Date'),
    (N'TrainingWalk', N'Date', N'IX_TrainingWalk_Date'),
    (N'TreadmillRun', N'Date', N'IX_TreadmillRun_Date'),
    (N'StationaryRide', N'Date', N'IX_StationaryRide_Date'),
    (N'Stairs', N'Date', N'IX_Stairs_Date'),
    (N'RecreationalRide', N'Date', N'IX_RecreationalRide_Date'),
    (N'RecreationalRun', N'Date', N'IX_RecreationalRun_Date'),
    (N'RecreationalWalk', N'Date', N'IX_RecreationalWalk_Date'),
    (N'LiftingSession', N'Date', N'IX_LiftingSession_Date');

UPDATE i SET State =
    CASE WHEN COL_LENGTH(N'dbo.' + QUOTENAME(i.TableName), i.ColumnName) IS NULL THEN N'NOT FOUND'
         WHEN EXISTS (SELECT 1 FROM sys.indexes AS x WHERE x.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(i.TableName)) AND x.name = i.Name) THEN N'exists'
         ELSE N'to create' END
FROM @I AS i;

SELECT TableName, ColumnName, Name, State FROM @I ORDER BY Seq;

IF EXISTS (SELECT 1 FROM @I WHERE State = N'NOT FOUND')
BEGIN
    RAISERROR(N'A table or column was not found (see above). Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @Count int = (SELECT COUNT(*) FROM @I WHERE State = N'to create');
IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count, N' index(es) to create; set @Apply = 1 to create them.');
    RETURN;
END;

DECLARE @sql nvarchar(max);
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(Name) + N' ON dbo.' + QUOTENAME(TableName) + N' (' + QUOTENAME(ColumnName) + N' ASC);'
        FROM @I WHERE State = N'to create' ORDER BY Seq;
    OPEN c; FETCH NEXT FROM c INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_executesql @sql; FETCH NEXT FROM c INTO @sql; END;
    CLOSE c; DEALLOCATE c;
    COMMIT;
    PRINT CONCAT(N'Created ', @Count, N' index(es).');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
