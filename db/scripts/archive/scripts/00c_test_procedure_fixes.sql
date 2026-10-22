-- =====================================================================================================
-- 00c_test_procedure_fixes.sql
-- Side-by-side test of the fixed procedures against the current (original) dbo procedures, on your real data.
-- Changes nothing in dbo: the fixed definitions are created in a scratch schema [fixtest], compared, and dropped.
-- Every call that could write -- the write tests, and the original procs that contain pasted-in GRANT statements --
-- runs inside a transaction that is rolled back. The only lasting trace is consumed identity values (gaps in Id) in
-- the tables the write tests touch: TrainingRide, RecreationalRide, StationaryRide, TrainingRun, TrainingWalk,
-- MissedMiles, Route, Weight, TrainingRideGPX, BikeOnlyMiles, LiftingSession.
-- Comparisons use the last complete calendar year that has training rides (printed at the start of Part 2).
--
-- Run (output to a text file is easiest to read):
--     sqlcmd -S <server> -d Fitness -E -I -i 00c_test_procedure_fixes.sql -o fixtest_results.txt
--
-- Reading the summary at the end:
--   MATCH            original and fixed return the same value
--   EXPECTED-DIFF    they differ in the direction/size the documented fix predicts (see Note)
--   UNEXPECTED-DIFF  they differ and they should not, or differ the wrong way -- send me this line
--   ORIG-ERROR       the original fails (expected where Note says so)
--   FIXED-ERROR      the fixed version fails -- send me this line
--   OK / FAIL        smoke tests of the fixed version only
-- =====================================================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO
IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing will be run.', 16, 1, DB_NAME());
    SET NOEXEC ON;
END;
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'fixtest'))
BEGIN
    RAISERROR(N'Schema [fixtest] already exists and contains objects. This script creates and drops [fixtest]; rename or remove it first.', 16, 1);
    SET NOEXEC ON;
END;
GO
IF SCHEMA_ID(N'fixtest') IS NULL EXEC (N'CREATE SCHEMA fixtest AUTHORIZATION dbo');
GO

-- ---------- Part 1: create the fixed objects in [fixtest]. A failure here is a compile error. ----------
-- fixtest.ExceptionalMiles
-- Changes:
--   * BUG: the "all bikes, date range" branch tested `@StartDate <> null`, which is never true, so it
--     always returned the all-time total. Replaced the four branches with one query using IS NULL logic.
--   * Date parameters are now `date`; the range is inclusive of the whole @EndDate day.
--   * Schema-qualified.
CREATE OR ALTER FUNCTION fixtest.ExceptionalMiles
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS int
AS
BEGIN
    RETURN COALESCE((
        SELECT SUM(bom.EndOdometer - bom.StartOdometer)
        FROM dbo.BikeOnlyMiles AS bom
        WHERE (@BikeId IS NULL OR @BikeId <= 0 OR bom.BikeId = @BikeId)
          AND (@StartDate IS NULL
               OR (bom.[Date] >= @StartDate AND bom.[Date] < DATEADD(day, 1, @EndDate)))
    ), 0);
END;
GO

-- fixtest.MaximumRideDate
-- Changes:
--   * Two lookups + IF collapsed into one query over both ride tables.
--   * Date parameters are now `date`; range inclusive of the whole @EndDate day.
--   * Kept: returns @StartDate when the bike has no rides in the range; return type still datetime.
CREATE OR ALTER FUNCTION fixtest.MaximumRideDate
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS datetime
AS
BEGIN
    RETURN COALESCE((
        SELECT MAX(r.RideDate)
        FROM (
            SELECT tr.[Date] AS RideDate FROM dbo.TrainingRide AS tr
            WHERE tr.BikeId = @BikeId AND tr.[Date] >= @StartDate AND tr.[Date] < DATEADD(day, 1, @EndDate)
            UNION ALL
            SELECT rr.[Date] FROM dbo.RecreationalRide AS rr
            WHERE rr.BikeId = @BikeId AND rr.[Date] >= @StartDate AND rr.[Date] < DATEADD(day, 1, @EndDate)
        ) AS r
    ), CAST(@StartDate AS datetime));
END;
GO

-- fixtest.MinimumRideDate
-- Changes:
--   * Two lookups + IF collapsed into one query over both ride tables.
--   * Date parameters are now `date`; range inclusive of the whole @EndDate day.
--   * BUG: each table's MIN was defaulted to @StartDate before the two were compared, so when only one of the two ride
--     tables had rides in the range the function returned @StartDate instead of the real earliest ride. Fixed.
--   * Kept: returns @StartDate when the bike has no rides in the range at all; return type still datetime.
CREATE OR ALTER FUNCTION fixtest.MinimumRideDate
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS datetime
AS
BEGIN
    RETURN COALESCE((
        SELECT MIN(r.RideDate)
        FROM (
            SELECT tr.[Date] AS RideDate FROM dbo.TrainingRide AS tr
            WHERE tr.BikeId = @BikeId AND tr.[Date] >= @StartDate AND tr.[Date] < DATEADD(day, 1, @EndDate)
            UNION ALL
            SELECT rr.[Date] FROM dbo.RecreationalRide AS rr
            WHERE rr.BikeId = @BikeId AND rr.[Date] >= @StartDate AND rr.[Date] < DATEADD(day, 1, @EndDate)
        ) AS r
    ), CAST(@StartDate AS datetime));
END;
GO

-- fixtest.OdometerReading
-- Changes:
--   * Five variables + a table variable replaced by one MAX over a VALUES list (the function is now
--     eligible for scalar UDF inlining once the database is at compatibility level 150+).
--   * @Date is now `date` (callers passing GETDATE() still get "everything up to today").
--   * Same five sources as before: training, recreational and stationary rides, non-ride and bike-only miles.
CREATE OR ALTER FUNCTION fixtest.OdometerReading
(
    @Date   date,
    @BikeId int
)
RETURNS int
AS
BEGIN
    RETURN COALESCE((
        SELECT MAX(v.Reading)
        FROM (VALUES
            ((SELECT MAX(x.EndOdometer) FROM dbo.RecreationalRide AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.TrainingRide     AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.StationaryRide   AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.NonRideMiles     AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date)),
            ((SELECT MAX(x.EndOdometer) FROM dbo.BikeOnlyMiles    AS x WHERE x.BikeId = @BikeId AND x.[Date] <= @Date))
        ) AS v(Reading)
    ), 0);
END;
GO

-- fixtest.ToDecimalHours
-- Changes:
--   * BUG: `RETURNS decimal` with no scale is decimal(18,0), so 1 h 30 m returned 2 instead of 1.5.
--     Now returns decimal(9,4).
CREATE OR ALTER FUNCTION fixtest.ToDecimalHours
(
    @Hours   int,
    @Minutes int
)
RETURNS decimal(9,4)
AS
BEGIN
    RETURN CAST(@Hours AS decimal(9,4)) + CAST(@Minutes AS decimal(9,4)) / 60.0;
END;
GO

-- fixtest.ClearRouteDirections
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE OR ALTER PROCEDURE fixtest.ClearRouteDirections
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Deleted int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.RouteDirection
        WHERE RouteId = @Id;

        SET @Deleted = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Deleted AS DeletedCount;
END;
GO

-- fixtest.ClearRoutePictures
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE OR ALTER PROCEDURE fixtest.ClearRoutePictures
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Deleted int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.RoutePicture
        WHERE RouteId = @RouteId;

        SET @Deleted = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Deleted AS DeletedCount;
END;
GO

-- fixtest.DeleteRoutePicture
-- Changes:
--   * Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.
CREATE OR ALTER PROCEDURE fixtest.DeleteRoutePicture
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Deleted int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.RoutePicture
        WHERE Id = @Id;

        SET @Deleted = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @Deleted AS DeletedCount;
END;
GO

-- fixtest.GetAverageGymHours
-- Changes:
--   * BUG: divide-by-zero when @StartDate = @EndDate (weeks = 0, then days/7 = 0). A single-day range now counts as 1/7 week.
--   * Estimates and the weeks divisor are otherwise unchanged (DATEDIFF(week), falling back to days/7).
--   * Range parameters are `date`, end date inclusive; result column named AverageWeeklyHours (float, as before).
CREATE OR ALTER PROCEDURE fixtest.GetAverageGymHours
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);
    DECLARE @Weeks float = DATEDIFF(week, @StartDate, @EndDate);

    IF @Weeks = 0
        SET @Weeks = DATEDIFF(day, @StartDate, @EndDate) / 7.0;
    IF @Weeks <= 0
        SET @Weeks = 1 / 7.0;

    SELECT CAST((
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TrainingRun    AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TreadmillRun   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.NumberOfSets)                   FROM dbo.LiftingSession AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 8.0
        + COALESCE((SELECT SUM(x.StairQuantity)                  FROM dbo.Stairs         AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 2400.0
        ) / @Weeks AS float) AS AverageWeeklyHours;
END;
GO

-- fixtest.GetAverageTemperature
-- Changes:
--   * Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
--   * Range parameters are `date`, end date inclusive; result column named AverageTemperature.
CREATE OR ALTER PROCEDURE fixtest.GetAverageTemperature
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(AVG(CAST(a.Temperature AS float)), 0) AS AverageTemperature
    FROM (
        SELECT x.Temperature FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.Temperature FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a;
END;
GO

-- fixtest.GetAverageWindSpeed
-- Changes:
--   * Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
--   * Range parameters are `date`, end date inclusive; result column named AverageWindSpeed.
CREATE OR ALTER PROCEDURE fixtest.GetAverageWindSpeed
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(AVG(CAST(a.WindSpeed AS float)), 0) AS AverageWindSpeed
    FROM (
        SELECT x.WindSpeed FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.WindSpeed FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a;
END;
GO

-- fixtest.GetBikeById
-- Changes:
--   * The Notes column came back unnamed (`COALESCE(Bike.Notes, '')` with no alias). Now aliased Notes.
--   * text columns cast to varchar(max) so callers get a modern type; AcquisitionDate added.
--   * Schema-qualified with table aliases.
CREATE OR ALTER PROCEDURE fixtest.GetBikeById
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT b.Id,
           b.[Name]                                        AS BikeName,
           bt.[Name]                                       AS TypeName,
           b.TypeId,
           b.BaseMiles,
           b.AcquisitionDate,
           COALESCE(CAST(b.Notes AS varchar(max)), '')     AS Notes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes
    FROM dbo.Bike AS b
    INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
    WHERE b.Id = @BikeId;
END;
GO

-- fixtest.GetBikeByName
-- Changes:
--   * Unnamed Notes column now aliased; text cast to varchar(max); AcquisitionDate added; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetBikeByName
    @BikeName varchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT b.Id,
           b.[Name]                                        AS BikeName,
           bt.[Name]                                       AS TypeName,
           b.TypeId,
           b.BaseMiles,
           b.AcquisitionDate,
           COALESCE(CAST(b.Notes AS varchar(max)), '')     AS Notes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes
    FROM dbo.Bike AS b
    INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
    WHERE b.[Name] = @BikeName;
END;
GO

-- fixtest.GetCircuitById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetCircuitById
    @CircuitId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    WHERE c.Id = @CircuitId;
END;
GO

-- fixtest.GetCircuitComponentById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetCircuitComponentById
    @CircuitComponentId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    WHERE cc.Id = @CircuitComponentId;
END;
GO

-- fixtest.GetCurrentBikePart
-- Changes:
--   * The same three-table join was written twice (outer query + MIN subquery). Rewritten as TOP (1) WITH TIES,
--     which returns exactly the same rows. The PartType join is no longer needed (filter on Part.PartTypeId).
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetCurrentBikePart
    @BikeId     int,
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1) WITH TIES
           bp.Id,
           bp.PartId
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part AS p ON p.Id = bp.PartId
    WHERE bp.BikeId     = @BikeId
      AND p.PartTypeId  = @PartTypeId
      AND bp.EndDate IS NULL
    ORDER BY bp.OdometerReading;
END;
GO

-- fixtest.GetCurrentBikePartsById
-- Changes:
--   * Two near-identical branches merged into one query; @BikeId = 0 still means "all bikes", and NULL now means the
--     same (previously NULL returned no rows).
--   * The single-bike branch had no ORDER BY; both now order by BikeId, PartTypeName.
--   * text Notes cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetCurrentBikePartsById
    @BikeId int = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id                                          AS PartId,
           p.[Name]                                      AS PartName,
           COALESCE(CAST(p.Notes AS varchar(max)), '')   AS PartNotes,
           m.Id                                          AS ManufacturerId,
           m.[Name]                                      AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')   AS ManufacturerNotes,
           pt.Id                                         AS PartTypeId,
           pt.[Name]                                     AS PartTypeName,
           COALESCE(CAST(pt.Notes AS varchar(max)), '')  AS PartTypeNotes,
           bp.BikeId
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part         AS p  ON p.Id  = bp.PartId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE bp.EndDate IS NULL
      AND (@BikeId IS NULL OR @BikeId = 0 OR bp.BikeId = @BikeId)
    ORDER BY bp.BikeId, pt.[Name]
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetExerciseHoursByDate
-- Changes:
--   * BUG: @LiftDivisor was int, so SUM(NumberOfSets) / @LiftDivisor was integer division (truncated). Now decimal.
--   * Zero, negative or NULL divisors raise an error instead of a divide-by-zero.
--   * SET NOCOUNT and the DECLAREs sat outside BEGIN...END; restructured.
--   * Range parameters are `date`, end date inclusive; result column named ExerciseHours.
CREATE OR ALTER PROCEDURE fixtest.GetExerciseHoursByDate
    @StartDate   date,
    @EndDate     date,
    @RideDivisor decimal(18,2),
    @RunDivisor  decimal(18,2),
    @LiftDivisor decimal(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@RideDivisor, 0) <= 0 OR COALESCE(@RunDivisor, 0) <= 0 OR COALESCE(@LiftDivisor, 0) <= 0
        THROW 50007, N'Divisors must be greater than zero.', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    -- Each component is rounded to decimal(18,2) before summing, exactly as the original's decimal(18,2) variables did.
    SELECT
          CAST(COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @RideDivisor AS decimal(18,2))
        + CAST(COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TrainingRun    AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @RunDivisor  AS decimal(18,2))
        + CAST(COALESCE((SELECT SUM(x.NumberOfSets)                   FROM dbo.LiftingSession AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @LiftDivisor AS decimal(18,2))
        AS ExerciseHours;
END;
GO

-- fixtest.GetLastEntries
-- Changes:
--   * SELECT * replaced by explicit columns; schema-qualified.
--   * Stairs added ("Last Stair Session") -- it was the only activity table missing from the list.
CREATE OR ALTER PROCEDURE fixtest.GetLastEntries
AS
BEGIN
    SET NOCOUNT ON;

    SELECT x.ActivityDate, x.Activity
    FROM (
        SELECT (SELECT MAX(t.[Date])    FROM dbo.LiftingSession   AS t) AS ActivityDate, N'Last Lifting Session'   AS Activity
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalRide AS t), N'Last Recreational Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalRun  AS t), N'Last Recreational Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.RecreationalWalk AS t), N'Last Recreational Walk'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.StationaryRide   AS t), N'Last Stationary Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingRide     AS t), N'Last Training Ride'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingRun      AS t), N'Last Training Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TrainingWalk     AS t), N'Last Training Walk'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.TreadmillRun     AS t), N'Last Treadmill Run'
        UNION ALL SELECT (SELECT MAX(t.StartTime) FROM dbo.Stairs           AS t), N'Last Stair Session'
        UNION ALL SELECT (SELECT MAX(t.[Date])    FROM dbo.[Weight]         AS t), N'Last Weight Reading'
    ) AS x
    WHERE x.ActivityDate IS NOT NULL
    ORDER BY x.ActivityDate DESC;
END;
GO

-- fixtest.GetMaintenanceByBikeId
-- Changes:
--   * BUG (broken today): filtered the MaintenanceLog view with `[Bike] = @BikeId`, but [Bike] is the bike *name*,
--     so every call failed converting the name to int. Now queries the base tables and filters on Maintenance.BikeId.
--   * The [Bike] column was selected twice; column names no longer contain spaces.
--   * text Notes cast to varchar(max); ORDER BY Odometer, Id.
CREATE OR ALTER PROCEDURE fixtest.GetMaintenanceByBikeId
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT mt.Id,
           mt.[Date]                                   AS OperationDate,
           b.[Name]                                    AS Bike,
           mf.[Name]                                   AS Manufacturer,
           p.[Name]                                    AS Part,
           pt.[Name]                                   AS PartType,
           mt.ActionTaken,
           mt.Odometer,
           COALESCE(CAST(mt.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Maintenance AS mt
    INNER JOIN dbo.Bike         AS b  ON b.Id  = mt.BikeId
    INNER JOIN dbo.Part         AS p  ON p.Id  = mt.PartId
    INNER JOIN dbo.Manufacturer AS mf ON mf.Id = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE mt.BikeId = @BikeId
    ORDER BY mt.Odometer, mt.Id;
END;
GO

-- fixtest.GetMaintenanceCount
-- Changes:
--   * Result column named MaintenanceCount; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetMaintenanceCount
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS MaintenanceCount
    FROM dbo.Maintenance AS mt
    WHERE mt.BikeId = @BikeId;
END;
GO

-- fixtest.GetMaintenanceSubset
-- Changes:
--   * BUG (broken today): same `[Bike] = @BikeId` name-vs-id comparison as GetMaintenanceByBikeId. Now filters on
--     Maintenance.BikeId against the base tables.
--   * ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with explicit columns and a deterministic order.
--   * Column names without spaces ([Operation Date] -> OperationDate, [Part Type] -> PartType, [Action Taken] ->
--     ActionTaken); Id added; the helper RowNumber column is no longer returned.
--   * @StartIndex is still 1-based; invalid or NULL paging arguments raise an error.
CREATE OR ALTER PROCEDURE fixtest.GetMaintenanceSubset
    @BikeId          int,
    @StartIndex      int,
    @NumberOfRecords int
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@StartIndex, 0) < 1 OR COALESCE(@NumberOfRecords, 0) < 1
        THROW 50005, N'StartIndex and NumberOfRecords must be 1 or greater.', 1;

    SELECT mt.Id,
           mt.[Date]                                   AS OperationDate,
           b.[Name]                                    AS Bike,
           mf.[Name]                                   AS Manufacturer,
           p.[Name]                                    AS Part,
           pt.[Name]                                   AS PartType,
           mt.ActionTaken,
           mt.Odometer,
           COALESCE(CAST(mt.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Maintenance AS mt
    INNER JOIN dbo.Bike         AS b  ON b.Id  = mt.BikeId
    INNER JOIN dbo.Part         AS p  ON p.Id  = mt.PartId
    INNER JOIN dbo.Manufacturer AS mf ON mf.Id = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE mt.BikeId = @BikeId
    ORDER BY mt.Odometer, mt.Id
    OFFSET @StartIndex - 1 ROWS FETCH NEXT @NumberOfRecords ROWS ONLY;
END;
GO

-- fixtest.GetManufacturerById
-- Changes:
--   * Notes added (cast from text); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetManufacturerById
    @ManufacturerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name],
           COALESCE(CAST(m.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Manufacturer AS m
    WHERE m.Id = @ManufacturerId;
END;
GO

-- fixtest.GetMaxOdometerByBike
-- Changes:
--   * Logic unchanged (despite the name it sums logged miles from all five odometer sources for the bike).
--   * One SELECT; result column named TotalLoggedMiles; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetMaxOdometerByBike
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide     AS x WHERE x.BikeId = @BikeId), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x WHERE x.BikeId = @BikeId), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide   AS x WHERE x.BikeId = @BikeId), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.BikeOnlyMiles    AS x WHERE x.BikeId = @BikeId), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.NonRideMiles     AS x WHERE x.BikeId = @BikeId), 0)
        AS TotalLoggedMiles;
END;
GO

-- fixtest.GetMilesByBikeByRideType
-- Changes:
--   * Five IF blocks replaced by one SELECT with CASE per source; an unknown @RideType raises an error
--     (previously returned 0 after adding three NULLs).
--   * Kept: the result is clamped at 0 (StationaryRide has no End > Start constraint, so trainer sums can be negative).
--   * Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + this bike's trainer,
--     4 this bike's trainer, 5 trainer rides with no bike (ignores @BikeId).
CREATE OR ALTER PROCEDURE fixtest.GetMilesByBikeByRideType
    @BikeId   int,
    @RideType int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT BETWEEN 1 AND 5
        THROW 50009, N'Unknown ride type (expected 1-5).', 1;

    SELECT CASE WHEN t.Miles < 0 THEN 0 ELSE t.Miles END AS Miles
    FROM (SELECT
          CASE WHEN @RideType IN (1, 3) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide     AS x WHERE x.BikeId = @BikeId), 0) ELSE 0 END
        + CASE WHEN @RideType = 2      THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x WHERE x.BikeId = @BikeId), 0) ELSE 0 END
        + CASE WHEN @RideType IN (3, 4) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide   AS x WHERE x.BikeId = @BikeId), 0) ELSE 0 END
        + CASE WHEN @RideType = 5      THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide   AS x WHERE x.BikeId IS NULL), 0) ELSE 0 END
        AS Miles) AS t;
END;
GO

-- fixtest.GetMilesByDateByBike
-- Changes:
--   * BUG: miles in a range were OdometerReading(@EndDate) - OdometerReading(@StartDate). OdometerReading includes
--     everything dated <= its argument, so every ride ON @StartDate was excluded. The start reading is now the last
--     reading *before* @StartDate, or -- if the bike has no earlier reading -- the lowest StartOdometer inside the range.
--   * Bike-only and trainer miles subtracted with the same inclusive range (previously ExceptionalMiles + a BETWEEN).
--   * @StartDate and @EndDate are independently optional (both NULL = all-time, as before).
--   * The clamp to 0 is kept: an odometer replacement can make a range negative.
--   * Result column named Miles; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByBike
    @StartDate      date = NULL,
    @EndDate        date = NULL,
    @BikeId         int,
    @IncludeTrainer bit
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, COALESCE(@EndDate, CAST(GETDATE() AS date)));

    WITH Readings AS (
        SELECT x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.TrainingRide     AS x WHERE x.BikeId = @BikeId
        UNION ALL
        SELECT x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.RecreationalRide AS x WHERE x.BikeId = @BikeId
        UNION ALL
        SELECT x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.StationaryRide   AS x WHERE x.BikeId = @BikeId
        UNION ALL
        SELECT x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.NonRideMiles     AS x WHERE x.BikeId = @BikeId
        UNION ALL
        SELECT x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.BikeOnlyMiles    AS x WHERE x.BikeId = @BikeId
    ),
    Odo AS (
        SELECT
            EndReading   = MAX(CASE WHEN r.[Date] < @EndExclusive THEN r.EndOdometer END),
            PriorReading = MAX(CASE WHEN @StartDate IS NOT NULL AND r.[Date] < @StartDate THEN r.EndOdometer END),
            FirstInRange = MIN(CASE WHEN (@StartDate IS NULL OR r.[Date] >= @StartDate) AND r.[Date] < @EndExclusive THEN r.StartOdometer END)
        FROM Readings AS r
    ),
    Deductions AS (
        SELECT
            BikeOnly = COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.BikeOnlyMiles  AS x
                                 WHERE x.BikeId = @BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0),
            Trainer  = COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x
                                 WHERE x.BikeId = @BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
    )
    SELECT Miles =
        CASE WHEN v.RangeMiles < 0 THEN 0 ELSE v.RangeMiles END
    FROM Odo AS o
    CROSS JOIN Deductions AS d
    CROSS APPLY (
        SELECT RangeMiles =
              COALESCE(o.EndReading, 0)
            - CASE WHEN @StartDate IS NULL THEN 0 ELSE COALESCE(o.PriorReading, o.FirstInRange, o.EndReading, 0) END
            - d.BikeOnly
            - CASE WHEN @IncludeTrainer = 1 THEN 0 ELSE d.Trainer END
    ) AS v;
END;
GO

-- fixtest.GetMilesByDateByBikeByRideType
-- Changes:
--   * Five IF blocks replaced by one SELECT with CASE per source; unknown @RideType raises an error; clamp at 0 kept.
--   * NULL @StartDate / @EndDate now mean "open-ended" (previously a NULL produced 0); end date inclusive.
--   * Result column named Miles. Ride types as in GetMilesByBikeByRideType.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByBikeByRideType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @BikeId    int,
    @RideType  int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT BETWEEN 1 AND 5
        THROW 50009, N'Unknown ride type (expected 1-5).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT CASE WHEN t.Miles < 0 THEN 0 ELSE t.Miles END AS Miles
    FROM (SELECT
          CASE WHEN @RideType IN (1, 3) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide AS x
                WHERE x.BikeId = @BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        + CASE WHEN @RideType = 2 THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x
                WHERE x.BikeId = @BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        + CASE WHEN @RideType IN (3, 4) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x
                WHERE x.BikeId = @BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        + CASE WHEN @RideType = 5 THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x
                WHERE x.BikeId IS NULL AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        AS Miles) AS t;
END;
GO

-- fixtest.GetMilesByDateByRideType
-- Changes:
--   * Four IF blocks (each with its own NULL-date branch) replaced by one SELECT; unknown @RideType raises an error;
--     clamp at 0 kept. @StartDate and @EndDate are independently optional; end date inclusive.
--   * Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + trainer (with a bike),
--     4 trainer (with a bike).
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByRideType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @RideType  int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT BETWEEN 1 AND 4
        THROW 50009, N'Unknown ride type (expected 1-4).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT CASE WHEN t.Miles < 0 THEN 0 ELSE t.Miles END AS Miles
    FROM (SELECT
          CASE WHEN @RideType IN (1, 3) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide AS x
                WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        + CASE WHEN @RideType = 2 THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x
                WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        + CASE WHEN @RideType IN (3, 4) THEN COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x
                WHERE x.BikeId IS NOT NULL AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0) ELSE 0 END
        AS Miles) AS t;
END;
GO

-- fixtest.GetMilesByDateByRunType
-- Changes:
--   * BUG: totals were stored in `int` variables, so every decimal Distance sum was truncated to whole miles.
--     Now returns decimal(12,4).
--   * Unknown @RunType raises an error (previously returned 0); optional, inclusive date range; result column named Miles.
--   Run types (unchanged): 1 training, 2 recreational.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByRunType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @RunType   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown run type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;
GO

-- fixtest.GetMilesByDateByShoe
-- Changes:
--   * BUG: two `GRANT EXECUTE` statements were pasted inside the body (no GO) and ran on every call. Removed.
--   * BUG: int variables truncated every decimal Distance sum, and stair miles used integer division
--     (SUM(ElevationGain) / 5280), so anything under a full vertical mile counted as 0. Now decimal arithmetic.
--   * Two duplicated branches (with / without dates) merged; @StartDate and @EndDate are independently optional.
--   * Result column named Miles (decimal(12,4)).
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByShoe
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @ShoeId    int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT CAST(
          COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingRun      AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingWalk     AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalRun  AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalWalk AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.Distance) FROM dbo.TreadmillRun     AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        + COALESCE((SELECT SUM(x.ElevationGain) / 5280.0 FROM dbo.Stairs AS x WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        AS decimal(12,4)) AS Miles;
END;
GO

-- fixtest.GetMilesByDateByShoeByRunType
-- Changes:
--   * BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
--   * Unknown type raises an error; clamp removed; optional, inclusive date range; result column named Miles.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByShoeByRunType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @ShoeId    int,
    @RunType   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown run type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;
GO

-- fixtest.GetMilesByDateByShoeByWalkType
-- Changes:
--   * BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
--   * Unknown type raises an error; clamp removed; optional, inclusive date range; result column named Miles.
--   * Parameter name @RunType kept for compatibility (it is the walk type: 1 training, 2 recreational).
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByShoeByWalkType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @ShoeId    int,
    @RunType   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown walk type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingWalk AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalWalk AS x
        WHERE x.ShoeId = @ShoeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;
GO

-- fixtest.GetMilesByDateByType
-- Changes:
--   * BUG: type 5 (treadmill) assigned the treadmill total to both the "training" and "recreational" variables and then
--     added them -- treadmill miles were doubled. Fixed.
--   * BUG: int variables truncated decimal run/walk/treadmill Distance sums. Now decimal(12,4).
--   * BUG (types 1 and 11): the range start used OdometerReading(@StartDate), which excluded rides on @StartDate
--     (see GetMilesByDateByBike). Same start-reading fix applied per bike.
--   * The per-bike cursor (declared twice in one proc) replaced by a single set-based query.
--   * Type 5 previously ignored the "NULL dates = all-time" convention; every type now honours it. With @EndDate NULL the
--     odometer reading is taken as of today (as before) and all other sums are open-ended (as before).
--   * Unknown @Type raises an error. Result column named Miles.
--   Types (unchanged): 1 rides excluding trainer, 11 rides including trainer, 2 runs, 3 walks,
--                      4 all stationary rides, 12 stationary rides with no bike, 5 treadmill runs.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 11, 2, 3, 4, 12, 5)
        THROW 50009, N'Unknown type (expected 1, 11, 2, 3, 4, 12 or 5).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, COALESCE(@EndDate, CAST(GETDATE() AS date)));

    IF @Type IN (1, 11)
    BEGIN
        WITH Readings AS (
            SELECT x.BikeId, x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.TrainingRide     AS x
            UNION ALL
            SELECT x.BikeId, x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.RecreationalRide AS x
            UNION ALL
            SELECT x.BikeId, x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.StationaryRide   AS x WHERE x.BikeId IS NOT NULL
            UNION ALL
            SELECT x.BikeId, x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.NonRideMiles     AS x
            UNION ALL
            SELECT x.BikeId, x.[Date], x.StartOdometer, x.EndOdometer FROM dbo.BikeOnlyMiles    AS x
        ),
        PerBike AS (
            SELECT r.BikeId,
                   EndReading   = MAX(CASE WHEN r.[Date] < @EndExclusive THEN r.EndOdometer END),
                   PriorReading = MAX(CASE WHEN @StartDate IS NOT NULL AND r.[Date] < @StartDate THEN r.EndOdometer END),
                   FirstInRange = MIN(CASE WHEN (@StartDate IS NULL OR r.[Date] >= @StartDate) AND r.[Date] < @EndExclusive THEN r.StartOdometer END)
            FROM Readings AS r
            GROUP BY r.BikeId
        ),
        PerBikeMiles AS (
            SELECT pb.BikeId,
                   RangeMiles =
                         COALESCE(pb.EndReading, 0)
                       - CASE WHEN @StartDate IS NULL THEN 0 ELSE COALESCE(pb.PriorReading, pb.FirstInRange, pb.EndReading, 0) END
                       - COALESCE(bo.Miles, 0)
                       - CASE WHEN @Type = 11 THEN 0 ELSE COALESCE(tr.Miles, 0) END
            FROM PerBike AS pb
            OUTER APPLY (SELECT SUM(x.EndOdometer - x.StartOdometer) AS Miles FROM dbo.BikeOnlyMiles AS x
                         WHERE x.BikeId = pb.BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)) AS bo
            OUTER APPLY (SELECT SUM(x.EndOdometer - x.StartOdometer) AS Miles FROM dbo.StationaryRide AS x
                         WHERE x.BikeId = pb.BikeId AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)) AS tr
        )
        SELECT CAST(COALESCE(SUM(pbm.RangeMiles), 0) AS decimal(12,4)) AS Miles
        FROM PerBikeMiles AS pbm;
        RETURN;
    END;

    SELECT CAST(COALESCE(CASE @Type
        WHEN 2 THEN
              COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingRun  AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
            + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalRun AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        WHEN 3 THEN
              COALESCE((SELECT SUM(x.Distance) FROM dbo.TrainingWalk AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
            + COALESCE((SELECT SUM(x.Distance) FROM dbo.RecreationalWalk AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive)), 0)
        WHEN 4 THEN
              (SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive))
        WHEN 12 THEN
              (SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x WHERE x.BikeId IS NULL AND (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive))
        WHEN 5 THEN
              (SELECT SUM(x.Distance) FROM dbo.TreadmillRun    AS x WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive))
        END, 0) AS decimal(12,4)) AS Miles;
END;
GO

-- fixtest.GetMilesByDateByWalkType
-- Changes:
--   * BUG: int variables truncated decimal Distance sums to whole miles. Now returns decimal(12,4).
--   * Unknown type raises an error; optional, inclusive date range; result column named Miles.
--   * Parameter name @RunType kept for compatibility (it is the walk type: 1 training, 2 recreational).
CREATE OR ALTER PROCEDURE fixtest.GetMilesByDateByWalkType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @RunType   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown walk type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingWalk AS x
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalWalk AS x
        WHERE (@StartDate IS NULL OR x.[Date] >= @StartDate) AND (@EndDate IS NULL OR x.[Date] < @EndExclusive);
END;
GO

-- fixtest.GetMilesByShoeByRunType
-- Changes:
--   * BUG: a `GRANT EXECUTE ON [dbo].[GetMilesByBikeByRideType] ...` (wrong object) was pasted inside the body after a
--     commented-out END, so it ran on every call. Removed.
--   * BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
--   * Unknown type raises an error; result column named Miles.
CREATE OR ALTER PROCEDURE fixtest.GetMilesByShoeByRunType
    @ShoeId  int,
    @RunType int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2)
        THROW 50009, N'Unknown run type (expected 1 or 2).', 1;

    IF @RunType = 1
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE x.ShoeId = @ShoeId;
    ELSE
        SELECT CAST(COALESCE(SUM(x.Distance), 0) AS decimal(12,4)) AS Miles
        FROM dbo.RecreationalRun AS x
        WHERE x.ShoeId = @ShoeId;
END;
GO

-- fixtest.GetMissedMilesByDateByType
-- Changes:
--   * @StartDate and @EndDate are independently optional (end inclusive); two branches merged.
--   * An unknown @TypeName raises an error instead of silently returning 0.
--   * Result column named Miles; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetMissedMilesByDateByType
    @StartDate date = NULL,
    @EndDate   date = NULL,
    @TypeName  nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExerciseTypeId int = (SELECT et.Id FROM dbo.ExerciseType AS et WHERE et.[Name] = @TypeName);

    IF @ExerciseTypeId IS NULL
        THROW 50003, N'Unknown exercise type name.', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(SUM(mm.Miles), 0) AS Miles
    FROM dbo.MissedMiles AS mm
    WHERE mm.ExerciseTypeId = @ExerciseTypeId
      AND (@StartDate IS NULL OR mm.[Date] >= @StartDate)
      AND (@EndDate   IS NULL OR mm.[Date] <  @EndExclusive);
END;
GO

-- fixtest.GetPartAge
-- Changes:
--   * The bike's current odometer is now fixtest.OdometerReading (all five odometer sources). The original looked only at
--     training and recreational rides, so trainer, non-ride and bike-only miles were ignored.
--   * Duplicate result column names (two columns called Name) fixed: ManufacturerName, PartName.
--   * New MilesOnPart column (OdometerReading - PartOdometer). The OdometerReading column keeps its original name.
--   * Duplicated join/subquery replaced by TOP (1) WITH TIES; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetPartAge
    @BikeId     int,
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BikeOdometer int = fixtest.OdometerReading(CAST(GETDATE() AS date), @BikeId);

    SELECT TOP (1) WITH TIES
           m.[Name]                             AS ManufacturerName,
           p.[Name]                             AS PartName,
           bp.StartDate,
           bp.OdometerReading                   AS PartOdometer,
           @BikeOdometer                        AS OdometerReading,
           @BikeOdometer - bp.OdometerReading   AS MilesOnPart
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part         AS p ON p.Id = bp.PartId
    INNER JOIN dbo.Manufacturer AS m ON m.Id = p.ManufacturerId
    WHERE bp.BikeId    = @BikeId
      AND p.PartTypeId = @PartTypeId
      AND bp.EndDate IS NULL
    ORDER BY bp.OdometerReading;
END;
GO

-- fixtest.GetPartById
-- Changes:
--   * BUG: LEFT JOIN to BikePart returned one row per installation, so a part fitted more than once came back as
--     several rows. Now returns exactly one row with the most recent installation (StartDate, EndDate, BikeId).
--   * text Notes cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetPartById
    @PartId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id                                         AS PartId,
           p.[Name]                                     AS PartName,
           COALESCE(CAST(p.Notes AS varchar(max)), '')  AS PartNotes,
           m.Id                                         AS ManufacturerId,
           m.[Name]                                     AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')  AS ManufacturerNotes,
           pt.Id                                        AS PartTypeId,
           pt.[Name]                                    AS PartTypeName,
           lastFit.BikeId,
           lastFit.StartDate,
           lastFit.EndDate
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    OUTER APPLY (
        SELECT TOP (1) bp.BikeId, bp.StartDate, bp.EndDate
        FROM dbo.BikePart AS bp
        WHERE bp.PartId = p.Id
        ORDER BY bp.StartDate DESC, bp.Id DESC
    ) AS lastFit
    WHERE p.Id = @PartId;
END;
GO

-- fixtest.GetPartCount
-- Changes:
--   * Result column named PartCount; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetPartCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS PartCount
    FROM dbo.Part;
END;
GO

-- fixtest.GetPartTypeById
-- Changes:
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetPartTypeById
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.Id = @PartTypeId;
END;
GO

-- fixtest.GetPartTypeByName
-- Changes:
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetPartTypeByName
    @PartTypeName nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.[Name] = @PartTypeName;
END;
GO

-- fixtest.GetRainDays
-- Changes:
--   * bit column compared to 1 instead of the string 'True'.
--   * Range parameters are `date`, end date inclusive; result column named RainActivities (it counts activities, not days).
CREATE OR ALTER PROCEDURE fixtest.GetRainDays
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT
          (SELECT COUNT(*) FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive AND x.Precipitation = 1)
        + (SELECT COUNT(*) FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive AND x.Precipitation = 1)
        AS RainActivities;
END;
GO

-- fixtest.GetRecreationalMilesByYear
-- Changes:
--   * YEAR([Date]) = @Year (non-SARGable) replaced by a date range; @Year NULL also means "all years".
--   * Result column named Miles; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetRecreationalMilesByYear
    @Year int = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.RecreationalRide AS x
    WHERE (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetRecreationalMilesByYearByBike
-- Changes:
--   * YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.
CREATE OR ALTER PROCEDURE fixtest.GetRecreationalMilesByYearByBike
    @Year   int = 0,
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.RecreationalRide AS x
    WHERE x.BikeId = @BikeId
      AND (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetRideDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only, so a multi-year range merged every January together. Now grouped by year and month.
--   * Column names without spaces: Year, MonthNumber, MonthName, Rides | Miles.
--   * An unknown @Type raises an error. Range parameters are `date`, end date inclusive.
CREATE OR ALTER PROCEDURE fixtest.GetRideDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Rides
        FROM dbo.TrainingRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.EndOdometer - x.StartOdometer) AS Miles
        FROM dbo.TrainingRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO

-- fixtest.GetRouteById
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetRouteById
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.Id,
           r.[Name],
           r.City,
           r.[State],
           r.Rating,
           r.TypeId,
           COALESCE(CAST(r.Notes AS varchar(max)), '') AS Notes
    FROM dbo.[Route] AS r
    WHERE r.Id = @RouteId;
END;
GO

-- fixtest.GetRouteDescriptionByRouteId
-- Changes:
--   * text Description cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetRouteDescriptionByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(rd.[Description] AS varchar(max)) AS [Description]
    FROM dbo.RouteDisplay AS rd
    WHERE rd.RouteId = @RouteId;
END;
GO

-- fixtest.GetRouteDirectionsByRouteId
-- Changes:
--   * CAST(... AS nvarchar) without a length replaced by an explicit length; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetRouteDirectionsByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rd.Id,
           rd.RouteId,
           rd.DirectionNumber,
           rd.DirectionMileMarker,
           rd.DirectionDescription,
           CONCAT(CAST(rd.DirectionMileMarker AS nvarchar(20)), N': ', rd.DirectionDescription) AS DirectionStep
    FROM dbo.RouteDirection AS rd
    WHERE rd.RouteId = @RouteId
    ORDER BY rd.DirectionNumber;
END;
GO

-- fixtest.GetRoutePicturesByRouteId
-- Changes:
--   * text ImageDescription cast to varchar(max); ORDER BY Id; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetRoutePicturesByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rp.Id,
           rp.RouteId,
           rp.ImageFileName,
           CAST(rp.ImageDescription AS varchar(max)) AS ImageDescription
    FROM dbo.RoutePicture AS rp
    WHERE rp.RouteId = @RouteId
    ORDER BY rp.Id;
END;
GO

-- fixtest.GetRunDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
--   * Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.
CREATE OR ALTER PROCEDURE fixtest.GetRunDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Runs
        FROM dbo.TrainingRun AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.Distance) AS Miles
        FROM dbo.TrainingRun AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO

-- fixtest.GetShoeById
-- Changes:
--   * Typo'd alias ShoeAquisitionDate corrected to ShoeAcquisitionDate.
--   * ntext Notes cast to nvarchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetShoeById
    @ShoeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.Id                                            AS ShoeId,
           s.[Name]                                        AS ShoeName,
           s.AcquisitionDate                               AS ShoeAcquisitionDate,
           s.RetireDate                                    AS ShoeRetireDate,
           COALESCE(CAST(s.Notes AS nvarchar(max)), N'')   AS ShoeNotes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes,
           st.Id                                           AS ShoeTypeId,
           st.[Name]                                       AS ShoeTypeName
    FROM dbo.Shoe AS s
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
    INNER JOIN dbo.ShoeType     AS st ON st.Id = s.ShoeTypeId
    WHERE s.Id = @ShoeId;
END;
GO

-- fixtest.GetStationaryRideDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
--   * Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.
CREATE OR ALTER PROCEDURE fixtest.GetStationaryRideDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Rides
        FROM dbo.StationaryRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.EndOdometer - x.StartOdometer) AS Miles
        FROM dbo.StationaryRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO

-- fixtest.GetTotalGymHours
-- Changes:
--   * Estimates kept exactly as before (by request): ride miles / 20, run miles / 7.6, sets / 8, stairs / 2400.
--   * Six SET statements collapsed into one SELECT; range parameters are `date`, end date inclusive.
--   * Result column named TotalHours (float, as before); schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetTotalGymHours
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT CAST(
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TrainingRun    AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TreadmillRun   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.NumberOfSets)                   FROM dbo.LiftingSession AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 8.0
        + COALESCE((SELECT SUM(x.StairQuantity)                  FROM dbo.Stairs         AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 2400.0
        AS float) AS TotalHours;
END;
GO

-- fixtest.GetTrainingMilesByYear
-- Changes:
--   * YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.
CREATE OR ALTER PROCEDURE fixtest.GetTrainingMilesByYear
    @Year int = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.TrainingRide AS x
    WHERE (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetTrainingMilesByYearByBike
-- Changes:
--   * YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.
CREATE OR ALTER PROCEDURE fixtest.GetTrainingMilesByYearByBike
    @Year   int = 0,
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.TrainingRide AS x
    WHERE x.BikeId = @BikeId
      AND (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetTreadmillRunDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
--   * Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.
CREATE OR ALTER PROCEDURE fixtest.GetTreadmillRunDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Runs
        FROM dbo.TreadmillRun AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.Distance) AS Miles
        FROM dbo.TreadmillRun AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO

-- fixtest.GetTrueTotalMiles
-- Changes:
--   * Logic unchanged (training + recreational odometer miles + every bike's BaseMiles); one SELECT, column TotalMiles.
CREATE OR ALTER PROCEDURE fixtest.GetTrueTotalMiles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide     AS x), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x), 0)
        + COALESCE((SELECT SUM(b.BaseMiles)                     FROM dbo.Bike             AS b), 0)
        AS TotalMiles;
END;
GO

-- fixtest.GetWalkDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
--   * The count column was mislabelled 'Runs'; now Walks.
--   * Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.
CREATE OR ALTER PROCEDURE fixtest.GetWalkDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Walks
        FROM dbo.TrainingWalk AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.Distance) AS Miles
        FROM dbo.TrainingWalk AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO

-- fixtest.GetWeightReadingsByDate
-- Changes:
--   * The NULL-defaulting IF statements sat outside BEGIN...END and before SET NOCOUNT ON. Restructured.
--   * NULL dates now mean "open-ended" directly in the WHERE clause (no extra MIN() lookup); end date is inclusive.
--   * Parameters are `date`; ORDER BY Date; Notes added; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.GetWeightReadingsByDate
    @StartDate date = NULL,
    @EndDate   date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT w.[Date],
           w.[Weight],
           w.BodyFatPercentage,
           COALESCE(CAST(w.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.[Weight] AS w
    WHERE (@StartDate IS NULL OR w.[Date] >= @StartDate)
      AND (@EndDate   IS NULL OR w.[Date] <  DATEADD(day, 1, @EndDate))
    ORDER BY w.[Date]
    OPTION (RECOMPILE);
END;
GO

-- fixtest.GetWindDistribution
-- Changes:
--   * BUG: UNION ALL of two GROUP BYs returned each direction twice (once for rides, once for runs). Now one row per
--     direction with the combined count.
--   * WindDirection returned trimmed (186 stored values carry a trailing space, e.g. 'W '). Cosmetic only: SQL Server
--     already ignores trailing spaces when grouping, so this does not change the counts.
--   * Count column renamed Activities (it counts activities, not days); ordered by direction.
CREATE OR ALTER PROCEDURE fixtest.GetWindDistribution
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT RTRIM(a.WindDirection) AS WindDirection,
           COUNT(*)               AS Activities
    FROM (
        SELECT x.WindDirection FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.WindDirection FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a
    GROUP BY RTRIM(a.WindDirection)
    ORDER BY RTRIM(a.WindDirection);
END;
GO

-- fixtest.InsertBike
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Name is varchar(50) to match the column (was nvarchar, implicit conversion); @Notes varchar(max) (was ntext into a text column).
--   * @AcquisitionDate is `date`; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertBike
    @Name            varchar(50),
    @ManufacturerId  int,
    @TypeId          int,
    @AcquisitionDate date,
    @BaseMiles       int = 0,
    @Notes           varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Bike
            ([Name], ManufacturerId, TypeId, AcquisitionDate, BaseMiles, Notes)
        VALUES
            (@Name, @ManufacturerId, @TypeId, @AcquisitionDate, @BaseMiles, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertBikeOnlyMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; transaction + TRY/CATCH.
--   * Rejects EndOdometer < StartOdometer (no table constraint enforces it).
--   * @Date is `date`; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertBikeOnlyMiles
    @Date          date,
    @StartOdometer int,
    @EndOdometer   int,
    @BikeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndOdometer < @StartOdometer
        THROW 50002, N'EndOdometer must not be less than StartOdometer.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BikeOnlyMiles
            ([Date], StartOdometer, EndOdometer, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertBikePart
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @StartDate is `date`; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertBikePart
    @BikeId          int,
    @PartId          int,
    @StartDate       date,
    @OdometerReading int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BikePart
            (BikeId, PartId, StartDate, OdometerReading)
        VALUES
            (@BikeId, @PartId, @StartDate, @OdometerReading);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertCircuit
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Notes nvarchar(max) instead of ntext; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertCircuit
    @Name  nvarchar(100),
    @Notes nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Circuit
            ([Name], Notes)
        VALUES
            (@Name, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertCircuitComponent
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Notes nvarchar(max) instead of ntext; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertCircuitComponent
    @ExerciseName nvarchar(100),
    @Notes        nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.CircuitComponent
            (ExerciseName, Notes)
        VALUES
            (@ExerciseName, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertCircuitsComponents
-- Changes:
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertCircuitsComponents
    @CircuitId          int,
    @CircuitComponentId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.CircuitsComponents
            (CircuitId, CircuitComponentId)
        VALUES
            (@CircuitId, @CircuitComponentId);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertLiftingSession
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Date `date`; @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertLiftingSession
    @Date         date,
    @CircuitId    int,
    @NumberOfSets int,
    @Notes        nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.LiftingSession
            ([Date], CircuitId, NumberOfSets, Notes)
        VALUES
            (@Date, @CircuitId, @NumberOfSets, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertMaintenance
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Date `date`; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertMaintenance
    @BikeId      int,
    @PartId      int,
    @ActionTaken nvarchar(50),
    @Date        date,
    @Odometer    int,
    @Notes       varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Maintenance
            (BikeId, PartId, ActionTaken, [Date], Odometer, Notes)
        VALUES
            (@BikeId, @PartId, @ActionTaken, @Date, @Odometer, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertManufacturer
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertManufacturer
    @Name  nvarchar(50),
    @Notes varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Manufacturer
            ([Name], Notes)
        VALUES
            (@Name, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertMissedMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: @Miles was `int`, so fractional missed miles were truncated before reaching the decimal(18,2) column.
--   * Explicit column list; @Date `date`; transaction + TRY/CATCH; now returns the new Id.
CREATE OR ALTER PROCEDURE fixtest.InsertMissedMiles
    @Date  date,
    @Miles decimal(18,2),
    @Type  int,
    @Notes nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MissedMiles
            ([Date], Miles, ExerciseTypeId, Notes)
        VALUES
            (@Date, @Miles, @Type, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertMissedMilesByType
-- Changes:
--   * BUG (broken today): INSERT without a column list supplied 3 values for 4 columns (Notes missing). Explicit column list now.
--   * New optional @Notes parameter.
--   * @TypeName nvarchar(50) to match ExerciseType.Name (was varchar); an unknown type name now raises an error
--     instead of attempting to insert a NULL ExerciseTypeId.
--   * @Date `date`; transaction + TRY/CATCH; returns the new Id.
CREATE OR ALTER PROCEDURE fixtest.InsertMissedMilesByType
    @Date     date,
    @Miles    decimal(18,2),
    @TypeName nvarchar(50),
    @Notes    nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ExerciseTypeId int = (SELECT et.Id FROM dbo.ExerciseType AS et WHERE et.[Name] = @TypeName);

    IF @ExerciseTypeId IS NULL
        THROW 50003, N'Unknown exercise type name.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MissedMiles
            ([Date], Miles, ExerciseTypeId, Notes)
        VALUES
            (@Date, @Miles, @ExerciseTypeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertNonRideMiles
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; transaction + TRY/CATCH.
--   * Rejects EndOdometer < StartOdometer.
--   * @Date is `date` (matches the column); now returns the new Id.
CREATE OR ALTER PROCEDURE fixtest.InsertNonRideMiles
    @Date          date,
    @StartOdometer int,
    @EndOdometer   int,
    @BikeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndOdometer < @StartOdometer
        THROW 50002, N'EndOdometer must not be less than StartOdometer.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.NonRideMiles
            ([Date], StartOdometer, EndOdometer, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @BikeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertPart
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertPart
    @ManufacturerId int,
    @PartTypeId     int,
    @Name           nvarchar(50),
    @Notes          varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Part
            (ManufacturerId, PartTypeId, [Name], Notes)
        VALUES
            (@ManufacturerId, @PartTypeId, @Name, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertPartType
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertPartType
    @Name  nvarchar(50),
    @Notes varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.PartType
            ([Name], Notes)
        VALUES
            (@Name, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 23 values for 25 columns. Explicit column list now.
--   * New optional parameters @Distance and @GpxJsonId.
--   * Ride and bike times computed with DATEDIFF(second); rejects EndTime/BikeEndTime earlier than StartTime.
--   * @MaxSpeed decimal(9,4) to match the column; @Date `date`; times datetime2(0); @Notes varchar(max).
--   * Transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalRide
    @Date           date,
    @StartOdometer  int,
    @EndOdometer    int,
    @StartTime      datetime2(0),
    @EndTime        datetime2(0),
    @BikeEndTime    datetime2(0),
    @AverageHR      int,
    @MaxHR          int,
    @AverageCadence int,
    @ElevationGain  int,
    @MaxSpeed       decimal(9,4),
    @Wind           nvarchar(255),
    @Temperature    int,
    @Precipitation  bit,
    @BikeId         int,
    @RouteId        int,
    @Notes          varchar(max) = NULL,
    @Distance       decimal(9,4) = NULL,
    @GpxJsonId      int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime OR @BikeEndTime < @StartTime
        THROW 50001, N'EndTime and BikeEndTime must not be earlier than StartTime.', 1;

    DECLARE @RideSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @BikeSeconds int = DATEDIFF(second, @StartTime, @BikeEndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             BikeEndTime, BikeTimeHours, BikeTimeMinutes, BikeTimeSeconds,
             AverageHR, MaxHR, AverageCadence, ElevationGain, MaxSpeed,
             Wind, Temperature, Precipitation, BikeId, RouteId, GpxJsonId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @BikeEndTime, @BikeSeconds / 3600, (@BikeSeconds % 3600) / 60, @BikeSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed,
             @Wind, @Temperature, @Precipitation, @BikeId, @RouteId, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalRideGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalRideGPX
    @RecreationalRideId int,
    @GPX                nvarchar(max),
    @Notes              nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRideGPX
            (RecreationalRideId, GPX, Notes)
        VALUES
            (@RecreationalRideId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalRun
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 21 values for 22 columns. Explicit column list now.
--   * New optional parameter @GpxJsonId.
--   * @Distance and @MaxSpeed decimal(9,4) to match the columns.
--   * Run and path times computed with DATEDIFF(second); rejects EndTime/PathEndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalRun
    @Date          date,
    @Distance      decimal(9,4),
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @PathEndTime   datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @MaxSpeed      decimal(9,4),
    @Wind          nvarchar(255),
    @Temperature   int,
    @Precipitation bit,
    @ShoeId        int,
    @RouteId       int,
    @Notes         varchar(max) = NULL,
    @GpxJsonId     int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime OR @PathEndTime < @StartTime
        THROW 50001, N'EndTime and PathEndTime must not be earlier than StartTime.', 1;

    DECLARE @RunSeconds  int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @PathSeconds int = DATEDIFF(second, @StartTime, @PathEndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRun
            ([Date], Distance, StartTime, EndTime,
             RunTimeHours, RunTimeMinutes, RunTimeSeconds,
             PathEndTime, PathTimeHours, PathTimeMinutes, PathTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             Wind, Temperature, Precipitation, ShoeId, RouteId, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @RunSeconds / 3600, (@RunSeconds % 3600) / 60, @RunSeconds % 60,
             @PathEndTime, @PathSeconds / 3600, (@PathSeconds % 3600) / 60, @PathSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @Wind, @Temperature, @Precipitation, @ShoeId, @RouteId, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalRunGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalRunGPX
    @RecreationalRunId int,
    @GPX               nvarchar(max),
    @Notes             nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalRunGPX
            (RecreationalRunId, GPX, Notes)
        VALUES
            (@RecreationalRunId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalWalk
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 21 values for 22 columns. Explicit column list now.
--   * New optional parameter @GpxJsonId.
--   * @Distance and @MaxSpeed decimal(9,4) to match the columns.
--   * Walk and path times computed with DATEDIFF(second); rejects EndTime/PathEndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalWalk
    @Date          date,
    @Distance      decimal(9,4),
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @PathEndTime   datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @MaxSpeed      decimal(9,4),
    @Wind          nvarchar(255),
    @Temperature   int,
    @Precipitation bit,
    @ShoeId        int,
    @RouteId       int,
    @Notes         varchar(max) = NULL,
    @GpxJsonId     int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime OR @PathEndTime < @StartTime
        THROW 50001, N'EndTime and PathEndTime must not be earlier than StartTime.', 1;

    DECLARE @WalkSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @PathSeconds int = DATEDIFF(second, @StartTime, @PathEndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalWalk
            ([Date], Distance, StartTime, EndTime,
             WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds,
             PathEndTime, PathTimeHours, PathTimeMinutes, PathTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             Wind, Temperature, Precipitation, ShoeId, RouteId, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @WalkSeconds / 3600, (@WalkSeconds % 3600) / 60, @WalkSeconds % 60,
             @PathEndTime, @PathSeconds / 3600, (@PathSeconds % 3600) / 60, @PathSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @Wind, @Temperature, @Precipitation, @ShoeId, @RouteId, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRecreationalWalkGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertRecreationalWalkGPX
    @RecreationalWalkId int,
    @GPX                nvarchar(max),
    @Notes              nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RecreationalWalkGPX
            (RecreationalWalkId, GPX, Notes)
        VALUES
            (@RecreationalWalkId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRoute
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * An unknown @TypeId (RouteType.EnumId) now raises an error instead of inserting a NULL TypeId.
--   * Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
--   * Kept: @TypeId is the RouteType *EnumId* and is mapped to RouteType.Id. UpdateRoute now does the same.
CREATE OR ALTER PROCEDURE fixtest.InsertRoute
    @Name   nvarchar(50),
    @City   nvarchar(50),
    @State  char(2),
    @TypeId int,
    @Rating int,
    @Notes  varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RouteTypeId int = (SELECT rt.Id FROM dbo.RouteType AS rt WHERE rt.EnumId = @TypeId);

    IF @RouteTypeId IS NULL
        THROW 50004, N'Unknown route type.', 1;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.[Route]
            ([Name], City, [State], TypeId, Rating, Notes)
        VALUES
            (@Name, @City, @State, @RouteTypeId, @Rating, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRouteDescription
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @Description varchar(max) instead of text; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertRouteDescription
    @RouteId     int,
    @Description varchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDisplay
            (RouteId, [Description])
        VALUES
            (@RouteId, @Description);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRouteDirection
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @DirectionDescription nvarchar(max) to match the column (was text -> implicit conversion);
--     @DirectionMileMarker decimal(18,1) to match the column.
--   * Explicit column list; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertRouteDirection
    @RouteId              int,
    @DirectionNumber      int,
    @DirectionMileMarker  decimal(18,1),
    @DirectionDescription nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RouteDirection
            (RouteId, DirectionNumber, DirectionMileMarker, DirectionDescription)
        VALUES
            (@RouteId, @DirectionNumber, @DirectionMileMarker, @DirectionDescription);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertRoutePicture
-- Changes:
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; @ImageDescription varchar(max) (column is NOT NULL text, so the empty-string default is kept).
--   * Transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertRoutePicture
    @RouteId          int,
    @ImageFileName    nvarchar(100),
    @ImageDescription varchar(max) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.RoutePicture
            (RouteId, ImageFileName, ImageDescription)
        VALUES
            (@RouteId, @ImageFileName, @ImageDescription);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertShoe
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * Explicit column list; dates are `date`; @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertShoe
    @Name            nvarchar(50),
    @ManufacturerId  int,
    @ShoeTypeId      int,
    @AcquisitionDate date,
    @RetireDate      date = NULL,
    @Notes           nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Shoe
            ([Name], ManufacturerId, ShoeTypeId, AcquisitionDate, RetireDate, Notes)
        VALUES
            (@Name, @ManufacturerId, @ShoeTypeId, @AcquisitionDate, @RetireDate, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertStairs
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list; stair time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
--   * Now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertStairs
    @Date          date,
    @StairQuantity int,
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @ShoeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @StairSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Stairs
            ([Date], StairQuantity, StartTime, EndTime,
             StairTimeHours, StairTimeMinutes, StairTimeSeconds,
             AverageHR, MaxHR, ElevationGain, ShoeId, Notes)
        VALUES
            (@Date, @StairQuantity, @StartTime, @EndTime,
             @StairSeconds / 3600, (@StairSeconds % 3600) / 60, @StairSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @ShoeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertStationaryRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 13 values for 14 columns. Explicit column list now.
--   * New optional parameter @Distance.
--   * Ride time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(); @Date `date`; times datetime2(0); @Notes nvarchar(max).
--   * Transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertStationaryRide
    @Date           date,
    @StartOdometer  int,
    @EndOdometer    int,
    @StartTime      datetime2(0),
    @EndTime        datetime2(0),
    @AverageHR      int,
    @MaxHR          int,
    @AverageCadence int,
    @BikeId         int           = NULL,
    @Notes          nvarchar(max) = NULL,
    @Distance       decimal(9,4)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RideSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.StationaryRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             AverageHR, MaxHR, AverageCadence, BikeId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @BikeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingRide
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 20 values for 24 columns, so every call failed.
--     Now uses an explicit column list.
--   * New optional parameters for the columns added since the proc was written:
--     @Distance, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
--   * Ride time computed from DATEDIFF(second) instead of DATEPART on datetime subtraction (no 24 h wrap, works with datetime2).
--   * Rejects EndTime earlier than StartTime.
--   * @MaxSpeed widened to decimal(9,4) to match the column (was decimal(5,2)); @Date is `date`; times are datetime2(0);
--     @Notes is varchar(max) (column is text; parameter type no longer deprecated).
--   * Transaction + TRY/CATCH; returns the new Id as an int column named Id.
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingRide
    @Date              date,
    @StartOdometer     int,
    @EndOdometer       int,
    @StartTime         datetime2(0),
    @EndTime           datetime2(0),
    @AverageHR         int,
    @MaxHR             int,
    @AverageCadence    int,
    @ElevationGain     int,
    @MaxSpeed          decimal(9,4),
    @WindSpeed         int,
    @WindDirection     nvarchar(3),
    @Temperature       int,
    @Precipitation     bit,
    @BikeId            int,
    @RouteId           int,
    @Notes             varchar(max)  = NULL,
    @Distance          decimal(9,4)  = NULL,
    @NumberOfAttempts  int           = 0,
    @NumberOfSuccesses int           = 0,
    @GpxJsonId         int           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RideSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRide
            ([Date], StartOdometer, EndOdometer, Distance, StartTime, EndTime,
             RideTimeHours, RideTimeMinutes, RideTimeSeconds,
             AverageHR, MaxHR, AverageCadence, ElevationGain, MaxSpeed,
             WindSpeed, WindDirection, Temperature, Precipitation,
             BikeId, RouteId, NumberOfAttempts, NumberOfSuccesses, GpxJsonId, Notes)
        VALUES
            (@Date, @StartOdometer, @EndOdometer, @Distance, @StartTime, @EndTime,
             @RideSeconds / 3600, (@RideSeconds % 3600) / 60, @RideSeconds % 60,
             @AverageHR, @MaxHR, @AverageCadence, @ElevationGain, @MaxSpeed,
             @WindSpeed, RTRIM(@WindDirection), @Temperature, @Precipitation,
             @BikeId, @RouteId, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingRideGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingRideGPX
    @TrainingRideId int,
    @GPX            nvarchar(max),
    @Notes          nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRideGPX
            (TrainingRideId, GPX, Notes)
        VALUES
            (@TrainingRideId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingRun
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 18 values for 21 columns. Explicit column list now.
--   * New optional parameters @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
--   * @Distance decimal(9,4) and @MaxSpeed decimal(9,4) to match the columns (were decimal(18,2) / decimal(5,2)).
--   * Run time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingRun
    @Date              date,
    @Distance          decimal(9,4),
    @StartTime         datetime2(0),
    @EndTime           datetime2(0),
    @AverageHR         int,
    @MaxHR             int,
    @ElevationGain     int,
    @MaxSpeed          decimal(9,4),
    @WindSpeed         int,
    @WindDirection     nvarchar(3),
    @Temperature       int,
    @Precipitation     bit,
    @ShoeId            int,
    @RouteId           int,
    @Notes             varchar(max) = NULL,
    @NumberOfAttempts  int          = 0,
    @NumberOfSuccesses int          = 0,
    @GpxJsonId         int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RunSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRun
            ([Date], Distance, StartTime, EndTime,
             RunTimeHours, RunTimeMinutes, RunTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             WindSpeed, WindDirection, Temperature, Precipitation,
             ShoeId, RouteId, NumberOfAttempts, NumberOfSuccesses, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @RunSeconds / 3600, (@RunSeconds % 3600) / 60, @RunSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @WindSpeed, RTRIM(@WindDirection), @Temperature, @Precipitation,
             @ShoeId, @RouteId, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingRunGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingRunGPX
    @TrainingRunId int,
    @GPX           nvarchar(max),
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingRunGPX
            (TrainingRunId, GPX, Notes)
        VALUES
            (@TrainingRunId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingWalk
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG (broken today): INSERT without a column list supplied 18 values for 21 columns. Explicit column list now.
--   * New optional parameters @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
--   * @Distance and @MaxSpeed decimal(9,4) to match the columns.
--   * Walk time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingWalk
    @Date              date,
    @Distance          decimal(9,4),
    @StartTime         datetime2(0),
    @EndTime           datetime2(0),
    @AverageHR         int,
    @MaxHR             int,
    @ElevationGain     int,
    @MaxSpeed          decimal(9,4),
    @WindSpeed         int,
    @WindDirection     nvarchar(3),
    @Temperature       int,
    @Precipitation     bit,
    @ShoeId            int,
    @RouteId           int,
    @Notes             varchar(max) = NULL,
    @NumberOfAttempts  int          = 0,
    @NumberOfSuccesses int          = 0,
    @GpxJsonId         int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @WalkSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingWalk
            ([Date], Distance, StartTime, EndTime,
             WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds,
             AverageHR, MaxHR, ElevationGain, MaxSpeed,
             WindSpeed, WindDirection, Temperature, Precipitation,
             ShoeId, RouteId, NumberOfAttempts, NumberOfSuccesses, GpxJsonId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @WalkSeconds / 3600, (@WalkSeconds % 3600) / 60, @WalkSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @MaxSpeed,
             @WindSpeed, RTRIM(@WindDirection), @Temperature, @Precipitation,
             @ShoeId, @RouteId, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTrainingWalkGPX
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran
--     on every call and failed for callers without GRANT rights. Removed.
--   * Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
--   * Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertTrainingWalkGPX
    @TrainingWalkId int,
    @GPX            nvarchar(max),
    @Notes          nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TrainingWalkGPX
            (TrainingWalkId, GPX, Notes)
        VALUES
            (@TrainingWalkId, @GPX, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertTreadmillRun
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * Explicit column list (worked today only because the table hasn't changed).
--   * @Distance decimal(9,4) to match the column; run time computed with DATEDIFF(second);
--     rejects EndTime earlier than StartTime.
--   * @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
--   * Now returns the new Id (previously returned nothing).
CREATE OR ALTER PROCEDURE fixtest.InsertTreadmillRun
    @Date          date,
    @Distance      decimal(9,4),
    @StartTime     datetime2(0),
    @EndTime       datetime2(0),
    @AverageHR     int,
    @MaxHR         int,
    @ElevationGain int,
    @ShoeId        int,
    @Notes         nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EndTime < @StartTime
        THROW 50001, N'EndTime must not be earlier than StartTime.', 1;

    DECLARE @RunSeconds int = DATEDIFF(second, @StartTime, @EndTime);
    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TreadmillRun
            ([Date], Distance, StartTime, EndTime,
             RunTimeHours, RunTimeMinutes, RunTimeSeconds,
             AverageHR, MaxHR, ElevationGain, ShoeId, Notes)
        VALUES
            (@Date, @Distance, @StartTime, @EndTime,
             @RunSeconds / 3600, (@RunSeconds % 3600) / 60, @RunSeconds % 60,
             @AverageHR, @MaxHR, @ElevationGain, @ShoeId, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.InsertWeightReading
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
--   * @Date `date` (UNIQUE_Date is on this column, so a time portion previously let two readings on one day slip in).
--   * @Notes nvarchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.InsertWeightReading
    @Date              date,
    @Weight            decimal(4,1),
    @BodyFatPercentage decimal(4,2),
    @Notes             nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NewId int;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Weight
            ([Date], [Weight], BodyFatPercentage, Notes)
        VALUES
            (@Date, @Weight, @BodyFatPercentage, @Notes);

        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @NewId AS Id;
END;
GO

-- fixtest.RemoveBikePart
-- Changes:
--   * @EndDate is `date`; raises an error if the BikePart row does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.RemoveBikePart
    @Id      int,
    @EndDate date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.BikePart
        SET EndDate = @EndDate
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'BikePart not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.SelectAllBikes
-- Changes:
--   * Unnamed Notes column now aliased; text cast to varchar(max); AcquisitionDate added; schema-qualified.
--   * Deterministic ORDER BY BikeName.
CREATE OR ALTER PROCEDURE fixtest.SelectAllBikes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT b.Id,
           b.[Name]                                        AS BikeName,
           bt.[Name]                                       AS TypeName,
           b.TypeId,
           b.BaseMiles,
           b.AcquisitionDate,
           COALESCE(CAST(b.Notes AS varchar(max)), '')     AS Notes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes
    FROM dbo.Bike AS b
    INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
    ORDER BY b.[Name];
END;
GO

-- fixtest.SelectAllCircuitComponents
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY ExerciseName; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllCircuitComponents
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    ORDER BY cc.ExerciseName;
END;
GO

-- fixtest.SelectAllCircuits
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllCircuits
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    ORDER BY c.[Name];
END;
GO

-- fixtest.SelectAllManufacturers
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllManufacturers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name]
    FROM dbo.Manufacturer AS m
    ORDER BY m.[Name];
END;
GO

-- fixtest.SelectAllPartTypes
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllPartTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    ORDER BY pt.[Name];
END;
GO

-- fixtest.SelectAllParts
-- Changes:
--   * text Notes cast to varchar(max); Part.Id added as tiebreaker in ORDER BY; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllParts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id,
           p.[Name],
           COALESCE(CAST(p.Notes AS varchar(max)), '') AS Notes,
           m.Id                                        AS ManufacturerId,
           m.[Name]                                    AS ManufacturerName,
           pt.Id                                       AS PartTypeId,
           pt.[Name]                                   AS PartTypeName
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    ORDER BY m.[Name], pt.[Name], p.Id;
END;
GO

-- fixtest.SelectAllPartsSubset
-- Changes:
--   * ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with an explicit column list.
--   * Paging is now deterministic (Part.Id tiebreaker; the original ORDER BY could reorder ties between pages).
--   * @StartIndex is still 1-based; values below 1, a non-positive page size or NULLs raise an error.
--   * The helper RowNumber column is no longer returned.
CREATE OR ALTER PROCEDURE fixtest.SelectAllPartsSubset
    @StartIndex      int,
    @NumberOfRecords int
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@StartIndex, 0) < 1 OR COALESCE(@NumberOfRecords, 0) < 1
        THROW 50005, N'StartIndex and NumberOfRecords must be 1 or greater.', 1;

    SELECT p.Id,
           m.[Name]                                    AS ManufacturerName,
           p.[Name],
           pt.[Name]                                   AS PartTypeName,
           COALESCE(CAST(p.Notes AS varchar(max)), '') AS Notes,
           pt.Id                                       AS PartTypeId,
           m.Id                                        AS ManufacturerId
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    ORDER BY m.[Name], pt.[Name], p.Id
    OFFSET @StartIndex - 1 ROWS FETCH NEXT @NumberOfRecords ROWS ONLY;
END;
GO

-- fixtest.SelectAllRidesByTypeByDate
-- Changes:
--   * Result sets had duplicate column names (BikeId x2, RouteTypeId x2, ManufacturerId x2, Name used for several
--     things), which ADO.NET renames to Name1, Name2... Every column now has one unique, prefixed name
--     (BikeName, RouteName, RouteCity, BikeManufacturerName, ...).
--   * Training rides now include the columns added since the proc was written: Distance, MaxSpeed,
--     NumberOfAttempts, NumberOfSuccesses, GpxJsonId. Recreational rides include Distance and GpxJsonId.
--   * text/ntext columns cast to (n)varchar(max); WindDirection trimmed; ORDER BY Date, StartTime.
--   * @StartDate and @EndDate are independently optional (end inclusive); an unknown @RideType raises an error.
--   Ride types (unchanged): 1 training, 2 recreational.
CREATE OR ALTER PROCEDURE fixtest.SelectAllRidesByTypeByDate
    @RideType  int,
    @StartDate date = NULL,
    @EndDate   date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT IN (1, 2)
        THROW 50009, N'Unknown ride type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @RideType = 1
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.TrainingRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE (@StartDate IS NULL OR r.[Date] >= @StartDate)
          AND (@EndDate   IS NULL OR r.[Date] <  @EndExclusive)
        ORDER BY r.[Date], r.StartTime
        OPTION (RECOMPILE);
    ELSE
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.BikeEndTime, r.BikeTimeHours, r.BikeTimeMinutes, r.BikeTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.RecreationalRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE (@StartDate IS NULL OR r.[Date] >= @StartDate)
          AND (@EndDate   IS NULL OR r.[Date] <  @EndExclusive)
        ORDER BY r.[Date], r.StartTime
        OPTION (RECOMPILE);
END;
GO

-- fixtest.SelectAllRidesByTypeById
-- Changes:
--   * BUG: type 3 (stationary) used `LEFT JOIN Bike ... INNER JOIN BikeType ... INNER JOIN Manufacturer`; the inner
--     joins cancelled the outer join, so a trainer ride with no bike (BikeId NULL) returned no row. All bike joins are
--     LEFT JOINs for type 3 now.
--   * Duplicate column names removed (same naming as SelectAllRidesByTypeByDate); Distance / GpxJsonId / attempt
--     columns included; text/ntext cast; WindDirection trimmed.
--   * An unknown @RideType raises an error.
--   Ride types (unchanged): 1 training, 2 recreational, 3 stationary.
CREATE OR ALTER PROCEDURE fixtest.SelectAllRidesByTypeById
    @RideType int,
    @Id       int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT IN (1, 2, 3)
        THROW 50009, N'Unknown ride type (expected 1, 2 or 3).', 1;

    IF @RideType = 1
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.TrainingRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE IF @RideType = 2
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.BikeEndTime, r.BikeTimeHours, r.BikeTimeMinutes, r.BikeTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.RecreationalRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence,
               COALESCE(CAST(r.Notes AS nvarchar(max)), N'') AS Notes,
               r.BikeId,
               b.[Name]                                      AS BikeName,
               b.ManufacturerId                              AS BikeManufacturerId,
               m.[Name]                                      AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')   AS BikeManufacturerNotes,
               b.TypeId                                      AS BikeTypeId,
               bt.EnumId                                     AS BikeTypeEnumId,
               bt.[Name]                                     AS BikeTypeName,
               b.AcquisitionDate                             AS BikeAcquisitionDate,
               b.BaseMiles                                   AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')   AS BikeNotes
        FROM dbo.StationaryRide AS r
        LEFT JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        LEFT JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        LEFT JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        WHERE r.Id = @Id;
END;
GO

-- fixtest.SelectAllRoutes
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllRoutes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.Id,
           r.[Name],
           r.City,
           r.[State],
           r.TypeId,
           rt.[Name]                                   AS TypeName,
           r.Rating,
           COALESCE(CAST(r.Notes AS varchar(max)), '') AS Notes
    FROM dbo.[Route] AS r
    INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId
    ORDER BY r.[Name];
END;
GO

-- fixtest.SelectAllRunsByTypeById
-- Changes:
--   * Duplicate column names removed (ShoeId x2, RouteId x2, RouteTypeId x2, ManufacturerId x2); prefixed names
--     (ShoeName, RouteName, ShoeManufacturerName, ...).
--   * Training runs now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational runs GpxJsonId.
--   * text/ntext cast; WindDirection trimmed; an unknown @RunType raises an error.
--   Run types (unchanged): 1 training, 2 recreational, 3 treadmill.
CREATE OR ALTER PROCEDURE fixtest.SelectAllRunsByTypeById
    @RunType int,
    @Id      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2, 3)
        THROW 50009, N'Unknown run type (expected 1, 2 or 3).', 1;

    IF @RunType = 1
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.TrainingRun AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE IF @RunType = 2
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
               r.PathEndTime, r.PathTimeHours, r.PathTimeMinutes, r.PathTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.RecreationalRun AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain,
               COALESCE(CAST(r.Notes AS nvarchar(max)), N'')  AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes
        FROM dbo.TreadmillRun AS r
        INNER JOIN dbo.Shoe         AS s ON s.Id = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m ON m.Id = s.ManufacturerId
        WHERE r.Id = @Id;
END;
GO

-- fixtest.SelectAllShoes
-- Changes:
--   * Typo'd alias ShoeAquisitionDate corrected to ShoeAcquisitionDate.
--   * ntext Notes cast to nvarchar(max); ORDER BY ShoeName; schema-qualified.
CREATE OR ALTER PROCEDURE fixtest.SelectAllShoes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.Id                                            AS ShoeId,
           s.[Name]                                        AS ShoeName,
           s.AcquisitionDate                               AS ShoeAcquisitionDate,
           s.RetireDate                                    AS ShoeRetireDate,
           COALESCE(CAST(s.Notes AS nvarchar(max)), N'')   AS ShoeNotes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes,
           st.Id                                           AS ShoeTypeId,
           st.[Name]                                       AS ShoeTypeName
    FROM dbo.Shoe AS s
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
    INNER JOIN dbo.ShoeType     AS st ON st.Id = s.ShoeTypeId
    ORDER BY s.[Name];
END;
GO

-- fixtest.SelectAllWalksByTypeById
-- Changes:
--   * Duplicate column names removed; prefixed names (ShoeName, RouteName, ShoeManufacturerName, ...).
--   * Training walks now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational walks GpxJsonId.
--   * text/ntext cast; WindDirection trimmed; an unknown @WalkType raises an error.
--   Walk types (unchanged): 1 training, 2 recreational.
CREATE OR ALTER PROCEDURE fixtest.SelectAllWalksByTypeById
    @WalkType int,
    @Id       int
AS
BEGIN
    SET NOCOUNT ON;

    IF @WalkType IS NULL OR @WalkType NOT IN (1, 2)
        THROW 50009, N'Unknown walk type (expected 1 or 2).', 1;

    IF @WalkType = 1
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.WalkTimeHours, r.WalkTimeMinutes, r.WalkTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.TrainingWalk AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.WalkTimeHours, r.WalkTimeMinutes, r.WalkTimeSeconds,
               r.PathEndTime, r.PathTimeHours, r.PathTimeMinutes, r.PathTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.RecreationalWalk AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
END;
GO

-- fixtest.SelectGPXByTypeById
-- Changes:
--   * The activity id column now has one name for every type (ActivityId) so callers can read any type the same way.
--   * An unknown @Type raises an error instead of silently returning no result set.
--   * Schema-qualified.
--   Type codes (unchanged): 1 TrainingRide, 2 TrainingRun, 6 RecreationalRide, 7 RecreationalRun,
--                           8 TrainingWalk, 9 RecreationalWalk.
CREATE OR ALTER PROCEDURE fixtest.SelectGPXByTypeById
    @Type int,
    @Id   int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2, 6, 7, 8, 9)
        THROW 50006, N'Unknown GPX activity type.', 1;

    IF @Type = 1
        SELECT g.Id, g.TrainingRideId AS ActivityId, g.GPX FROM dbo.TrainingRideGPX AS g WHERE g.TrainingRideId = @Id;
    ELSE IF @Type = 2
        SELECT g.Id, g.TrainingRunId AS ActivityId, g.GPX FROM dbo.TrainingRunGPX AS g WHERE g.TrainingRunId = @Id;
    ELSE IF @Type = 6
        SELECT g.Id, g.RecreationalRideId AS ActivityId, g.GPX FROM dbo.RecreationalRideGPX AS g WHERE g.RecreationalRideId = @Id;
    ELSE IF @Type = 7
        SELECT g.Id, g.RecreationalRunId AS ActivityId, g.GPX FROM dbo.RecreationalRunGPX AS g WHERE g.RecreationalRunId = @Id;
    ELSE IF @Type = 8
        SELECT g.Id, g.TrainingWalkId AS ActivityId, g.GPX FROM dbo.TrainingWalkGPX AS g WHERE g.TrainingWalkId = @Id;
    ELSE
        SELECT g.Id, g.RecreationalWalkId AS ActivityId, g.GPX FROM dbo.RecreationalWalkGPX AS g WHERE g.RecreationalWalkId = @Id;
END;
GO

-- fixtest.UpdateBaseMiles
-- Changes:
--   * BUG: read BaseMiles into a variable, then wrote variable + @Miles back -- not atomic, so two concurrent calls
--     could lose an update. Now a single `SET BaseMiles = BaseMiles + @Miles`.
--   * Raises an error if the bike does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdateBaseMiles
    @BikeId int,
    @Miles  int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Bike
        SET BaseMiles = BaseMiles + @Miles
        WHERE Id = @BikeId;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Bike not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.UpdateBikeNotes
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * @Notes was nvarchar(255) writing into a text column (silent truncation at 255, implicit conversion).
--     Now varchar(max).
--   * Raises an error if the bike does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdateBikeNotes
    @Id    int,
    @Notes varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Bike
        SET Notes = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Bike not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.UpdatePart
-- Changes:
--   * @Notes now defaults to NULL (was '').
--   * @Notes was nvarchar(255) writing into a text column (silent truncation at 255). Now varchar(max).
--   * Raises an error if the part does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdatePart
    @Id             int,
    @ManufacturerId int,
    @PartTypeId     int,
    @Name           nvarchar(50),
    @Notes          varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Part
        SET ManufacturerId = @ManufacturerId,
            PartTypeId     = @PartTypeId,
            [Name]         = @Name,
            Notes          = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Part not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.UpdateRoute
-- Changes:
--   * BUG: InsertRoute maps its type argument through RouteType.EnumId, but UpdateRoute wrote @RouteType straight into
--     Route.TypeId. Both now map through EnumId. (Harmless with today's data, where Id = EnumId for both route types,
--     but the two procs disagreed about what the parameter meant.)
--   * Raises an error if the route or route type does not exist.
--   * @Notes varchar(max); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdateRoute
    @Id        int,
    @Name      nvarchar(50),
    @City      nvarchar(50),
    @State     char(2),
    @RouteType int,
    @Rating    int,
    @Notes     varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RouteTypeId int = (SELECT rt.Id FROM dbo.RouteType AS rt WHERE rt.EnumId = @RouteType);

    IF @RouteTypeId IS NULL
        THROW 50004, N'Unknown route type.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.[Route]
        SET [Name]  = @Name,
            City    = @City,
            [State] = @State,
            TypeId  = @RouteTypeId,
            Rating  = @Rating,
            Notes   = @Notes
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.UpdateRouteDescription
-- Changes:
--   * @Description varchar(max) instead of text.
--   * Raises an error if the route has no description row (previously a silent no-op); transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdateRouteDescription
    @RouteId     int,
    @Description varchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.RouteDisplay
        SET [Description] = @Description
        WHERE RouteId = @RouteId;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route description not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.UpdateRoutePicture
-- Changes:
--   * @ImageDescription varchar(max) instead of text.
--   * Raises an error if the picture does not exist; transaction + TRY/CATCH.
CREATE OR ALTER PROCEDURE fixtest.UpdateRoutePicture
    @Id               int,
    @ImageFileName    nvarchar(100),
    @ImageDescription varchar(max) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.RoutePicture
        SET ImageFileName    = @ImageFileName,
            ImageDescription = @ImageDescription
        WHERE Id = @Id;

        IF @@ROWCOUNT = 0
            THROW 50010, N'Route picture not found.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- fixtest.SelectAllRidesByType
-- Changes:
--   * Was a copy of SelectAllRidesByTypeByDate without the WHERE clause (3,600 characters duplicated, and the two had
--     already drifted: one returned Notes raw, the other coalesced). Now delegates to SelectAllRidesByTypeByDate with
--     no date limits, so both return exactly the same columns. See that procedure for the column changes.
CREATE OR ALTER PROCEDURE fixtest.SelectAllRidesByType
    @RideType int
AS
BEGIN
    SET NOCOUNT ON;

    EXEC fixtest.SelectAllRidesByTypeByDate @RideType = @RideType, @StartDate = NULL, @EndDate = NULL;
END;
GO


-- ---------- Part 2: comparisons, smoke tests and rolled-back write tests ----------
DECLARE @Yr int = (SELECT YEAR(MAX([Date])) - 1 FROM dbo.TrainingRide);
DECLARE @S date = DATEFROMPARTS(@Yr, 1, 1), @E date = DATEFROMPARTS(@Yr, 12, 31), @OneDay date = DATEFROMPARTS(@Yr, 6, 5);
DECLARE @Bike int = (SELECT TOP (1) BikeId FROM dbo.TrainingRide WHERE [Date] >= @S AND [Date] <= @E GROUP BY BikeId ORDER BY COUNT(*) DESC);
DECLARE @BikeName varchar(50) = (SELECT [Name] FROM dbo.Bike WHERE Id = @Bike);
DECLARE @Shoe int = (SELECT TOP (1) ShoeId FROM dbo.TrainingWalk GROUP BY ShoeId ORDER BY COUNT(*) DESC);
DECLARE @ExType nvarchar(50) = (SELECT TOP (1) et.[Name] FROM dbo.MissedMiles AS mm JOIN dbo.ExerciseType AS et ON et.Id = mm.ExerciseTypeId GROUP BY et.[Name] ORDER BY COUNT(*) DESC);
DECLARE @ExTypeId int = (SELECT Id FROM dbo.ExerciseType WHERE [Name] = @ExType);
DECLARE @Circuit int = (SELECT MIN(Id) FROM dbo.Circuit), @CircuitComponent int = (SELECT MIN(Id) FROM dbo.CircuitComponent);
DECLARE @Manufacturer int = (SELECT MIN(Id) FROM dbo.Manufacturer), @Part int = (SELECT TOP (1) PartId FROM dbo.BikePart GROUP BY PartId ORDER BY COUNT(*) DESC);
DECLARE @PartType int = (SELECT TOP (1) p.PartTypeId FROM dbo.BikePart AS bp JOIN dbo.Part AS p ON p.Id = bp.PartId WHERE bp.BikeId = @Bike AND bp.EndDate IS NULL);
DECLARE @PartTypeName nvarchar(50) = (SELECT [Name] FROM dbo.PartType WHERE Id = @PartType);
DECLARE @Route int = (SELECT TOP (1) RouteId FROM dbo.TrainingRide GROUP BY RouteId ORDER BY COUNT(*) DESC);
DECLARE @TrainingRide int = (SELECT MAX(Id) FROM dbo.TrainingRide), @RecRide int = (SELECT MAX(Id) FROM dbo.RecreationalRide);
DECLARE @StatRide int = (SELECT MAX(Id) FROM dbo.StationaryRide WHERE BikeId IS NOT NULL), @StatRideNoBike int = (SELECT MAX(Id) FROM dbo.StationaryRide WHERE BikeId IS NULL);
DECLARE @TrainingRun int = (SELECT MAX(Id) FROM dbo.TrainingRun), @Treadmill int = (SELECT MAX(Id) FROM dbo.TreadmillRun), @TrainingWalk int = (SELECT MAX(Id) FROM dbo.TrainingWalk);
DECLARE @Lift int = (SELECT MIN(Id) FROM dbo.Circuit), @RouteType int = (SELECT MIN(EnumId) FROM dbo.RouteType);

PRINT CONCAT(N'Test parameters: year=', @Yr, N' bike=', @Bike, N' shoe=', @Shoe, N' exerciseType=', @ExType, N' route=', @Route,
             N' partType=', @PartType, N' trainingRide=', @TrainingRide);

DECLARE @Results TABLE (Seq int IDENTITY, Test nvarchar(300), Outcome varchar(20), Original nvarchar(400), Fixed nvarchar(400), Note nvarchar(300));  -- table variable: survives ROLLBACK
CREATE TABLE #v (v float);
DECLARE @o float, @f float, @oe nvarchar(400), @fe nvarchar(400), @sql nvarchar(max), @params nvarchar(max), @id int, @err int, @msg nvarchar(400);
SET @params = N'@S date, @E date, @OneDay date, @Yr int, @Bike int, @Shoe int, @ExType nvarchar(50), @BikeName varchar(50), @Circuit int, @CircuitComponent int, @Manufacturer int, @Part int, @PartType int, @PartTypeName nvarchar(50), @Route int, @TrainingRide int, @RecRide int, @StatRide int, @StatRideNoBike int, @TrainingRun int, @Treadmill int, @TrainingWalk int';

SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTotalGymHours @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTotalGymHours @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTotalGymHours @StartDate=@S, @EndDate=@E',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetAverageGymHours @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetAverageGymHours @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetAverageGymHours @StartDate=@S, @EndDate=@E',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetAverageGymHours @StartDate=@OneDay, @EndDate=@OneDay;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetAverageGymHours @StartDate=@OneDay, @EndDate=@OneDay;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetAverageGymHours @StartDate=@OneDay, @EndDate=@OneDay',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'origerr' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'origerr' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'origerr' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original divides by zero on a one-day range';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetExerciseHoursByDate @StartDate=@S, @EndDate=@E, @RideDivisor=20, @RunDivisor=7.6, @LiftDivisor=8;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetExerciseHoursByDate @StartDate=@S, @EndDate=@E, @RideDivisor=20, @RunDivisor=7.6, @LiftDivisor=8;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetExerciseHoursByDate @StartDate=@S, @EndDate=@E, @RideDivisor=20, @RunDivisor=7.6, @LiftDivisor=8',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated lifting hours (integer division)';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetAverageTemperature @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetAverageTemperature @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetAverageTemperature @StartDate=@S, @EndDate=@E',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetAverageWindSpeed @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetAverageWindSpeed @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetAverageWindSpeed @StartDate=@S, @EndDate=@E',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetRainDays @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetRainDays @StartDate=@S, @EndDate=@E;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetRainDays @StartDate=@S, @EndDate=@E',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTrueTotalMiles ;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTrueTotalMiles ;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTrueTotalMiles ',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetPartCount ;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetPartCount ;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetPartCount ',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMaintenanceCount @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMaintenanceCount @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMaintenanceCount @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMaxOdometerByBike @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMaxOdometerByBike @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMaxOdometerByBike @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByBikeByRideType @BikeId=@Bike, @RideType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByBikeByRideType @BikeId=@Bike, @RideType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByBikeByRideType @BikeId=@Bike, @RideType=3',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=3',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByBikeByRideType @BikeId=@Bike, @RideType=4',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=4',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByBikeByRideType @BikeId=@Bike, @RideType=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByBikeByRideType @BikeId=@Bike, @RideType=5',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBikeByRideType @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @RideType=5',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=3',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRideType @StartDate=@S, @EndDate=@E, @RideType=4',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRideType @StartDate=NULL, @EndDate=NULL, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRideType @StartDate=NULL, @EndDate=NULL, @RideType=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRideType @StartDate=NULL, @EndDate=NULL, @RideType=3',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles (original also runs a pasted-in GRANT; rolled back)';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByRunType @StartDate=@S, @EndDate=@E, @RunType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByWalkType @StartDate=@S, @EndDate=@E, @RunType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoeByRunType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoeByWalkType @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe, @RunType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByShoeByRunType @ShoeId=@Shoe, @RunType=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles (original also runs a pasted-in GRANT; rolled back)';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoe @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoe @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoe @StartDate=@S, @EndDate=@E, @ShoeId=@Shoe',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated each activity total and stair miles (rolled-back GRANT)';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByShoe @StartDate=NULL, @EndDate=NULL, @ShoeId=@Shoe;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByShoe @StartDate=NULL, @EndDate=NULL, @ShoeId=@Shoe;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByShoe @StartDate=NULL, @EndDate=NULL, @ShoeId=@Shoe',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated each activity total and stair miles (rolled-back GRANT)';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original excluded rides on the start date';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=11;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=11;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=11',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original excluded rides on the start date';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=2;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=2',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=3;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=3',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge1' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge1' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original truncated decimal miles to whole miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=4;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=4',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=12;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=12;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=12',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=5;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=@S, @EndDate=@E, @Type=5',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'half' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'half' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'half' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original doubled treadmill miles';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByType @StartDate=NULL, @EndDate=NULL, @Type=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByType @StartDate=NULL, @EndDate=NULL, @Type=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByType @StartDate=NULL, @EndDate=NULL, @Type=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=0',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original excluded rides on the start date';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=0',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBike @StartDate=@S, @EndDate=@E, @BikeId=@Bike, @IncludeTrainer=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'ge' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'ge' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'original excluded rides on the start date';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=1;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMilesByDateByBike @StartDate=NULL, @EndDate=NULL, @BikeId=@Bike, @IncludeTrainer=1',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMissedMilesByDateByType @StartDate=@S, @EndDate=@E, @TypeName=@ExType;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMissedMilesByDateByType @StartDate=@S, @EndDate=@E, @TypeName=@ExType;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMissedMilesByDateByType @StartDate=@S, @EndDate=@E, @TypeName=@ExType',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetMissedMilesByDateByType @StartDate=NULL, @EndDate=NULL, @TypeName=@ExType;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetMissedMilesByDateByType @StartDate=NULL, @EndDate=NULL, @TypeName=@ExType;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetMissedMilesByDateByType @StartDate=NULL, @EndDate=NULL, @TypeName=@ExType',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetRecreationalMilesByYear @Year=@Yr;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetRecreationalMilesByYear @Year=@Yr;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetRecreationalMilesByYear @Year=@Yr',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetRecreationalMilesByYear @Year=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetRecreationalMilesByYear @Year=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetRecreationalMilesByYear @Year=0',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTrainingMilesByYear @Year=@Yr;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTrainingMilesByYear @Year=@Yr;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTrainingMilesByYear @Year=@Yr',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTrainingMilesByYear @Year=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTrainingMilesByYear @Year=0;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTrainingMilesByYear @Year=0',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetRecreationalMilesByYearByBike @Year=@Yr, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetRecreationalMilesByYearByBike @Year=@Yr, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetRecreationalMilesByYearByBike @Year=@Yr, @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetRecreationalMilesByYearByBike @Year=0, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetRecreationalMilesByYearByBike @Year=0, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetRecreationalMilesByYearByBike @Year=0, @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTrainingMilesByYearByBike @Year=@Yr, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTrainingMilesByYearByBike @Year=@Yr, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTrainingMilesByYearByBike @Year=@Yr, @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
SELECT @o = NULL, @f = NULL, @oe = NULL, @fe = NULL;
BEGIN TRY
    BEGIN TRANSACTION;   -- some originals run pasted-in GRANT statements; this undoes them
    DELETE #v; SET @sql = N'INSERT #v EXEC dbo.GetTrainingMilesByYearByBike @Year=0, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @o = MAX(v) FROM #v;
    ROLLBACK TRANSACTION;
END TRY BEGIN CATCH SET @oe = LEFT(ERROR_MESSAGE(), 400); IF XACT_STATE() <> 0 ROLLBACK TRANSACTION; END CATCH;
BEGIN TRY
    DELETE #v; SET @sql = N'INSERT #v EXEC fixtest.GetTrainingMilesByYearByBike @Year=0, @BikeId=@Bike;';
    EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    SELECT @f = MAX(v) FROM #v;
END TRY BEGIN CATCH SET @fe = LEFT(ERROR_MESSAGE(), 400); END CATCH;
INSERT @Results (Test, Outcome, Original, Fixed, Note)
SELECT N'GetTrainingMilesByYearByBike @Year=0, @BikeId=@Bike',
       CASE WHEN @fe IS NOT NULL THEN 'FIXED-ERROR'
            WHEN @oe IS NOT NULL THEN 'ORIG-ERROR'
            WHEN ABS(COALESCE(@o, 0) - COALESCE(@f, 0)) < 0.00005 THEN 'MATCH'
            WHEN 'same' = 'ge'   AND COALESCE(@f, 0) >= COALESCE(@o, 0) THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'ge1'  AND COALESCE(@f, 0) - COALESCE(@o, 0) BETWEEN 0 AND 1 THEN 'EXPECTED-DIFF'
            WHEN 'same' = 'half' AND ABS(COALESCE(@o, 0) - 2 * COALESCE(@f, 0)) < 0.0001 THEN 'EXPECTED-DIFF'
            ELSE 'UNEXPECTED-DIFF' END,
       COALESCE(@oe, CONVERT(nvarchar(50), @o, 3)), COALESCE(@fe, CONVERT(nvarchar(50), @f, 3)), N'';
PRINT N'--- Smoke tests: the result sets below come from the fixed procedures ---';
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetBikeById @BikeId=@Bike;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetBikeById @BikeId=@Bike', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetBikeById @BikeId=@Bike', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetBikeByName @BikeName=@BikeName;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetBikeByName @BikeName=@BikeName', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetBikeByName @BikeName=@BikeName', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllBikes ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllBikes ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllBikes ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetCircuitById @CircuitId=@Circuit;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetCircuitById @CircuitId=@Circuit', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetCircuitById @CircuitId=@Circuit', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetCircuitComponentById @CircuitComponentId=@CircuitComponent;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetCircuitComponentById @CircuitComponentId=@CircuitComponent', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetCircuitComponentById @CircuitComponentId=@CircuitComponent', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllCircuits ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllCircuits ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllCircuits ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllCircuitComponents ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllCircuitComponents ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllCircuitComponents ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetManufacturerById @ManufacturerId=@Manufacturer;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetManufacturerById @ManufacturerId=@Manufacturer', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetManufacturerById @ManufacturerId=@Manufacturer', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllManufacturers ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllManufacturers ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllManufacturers ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetPartById @PartId=@Part;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetPartById @PartId=@Part', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetPartById @PartId=@Part', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetPartTypeById @PartTypeId=@PartType;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetPartTypeById @PartTypeId=@PartType', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetPartTypeById @PartTypeId=@PartType', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetPartTypeByName @PartTypeName=@PartTypeName;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetPartTypeByName @PartTypeName=@PartTypeName', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetPartTypeByName @PartTypeName=@PartTypeName', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllParts ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllParts ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllParts ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllPartsSubset @StartIndex=1, @NumberOfRecords=10;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllPartsSubset @StartIndex=1, @NumberOfRecords=10', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllPartsSubset @StartIndex=1, @NumberOfRecords=10', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllPartTypes ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllPartTypes ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllPartTypes ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRouteById @RouteId=@Route;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRouteById @RouteId=@Route', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRouteById @RouteId=@Route', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRouteDescriptionByRouteId @RouteId=@Route;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRouteDescriptionByRouteId @RouteId=@Route', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRouteDescriptionByRouteId @RouteId=@Route', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRouteDirectionsByRouteId @RouteId=@Route;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRouteDirectionsByRouteId @RouteId=@Route', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRouteDirectionsByRouteId @RouteId=@Route', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRoutePicturesByRouteId @RouteId=@Route;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRoutePicturesByRouteId @RouteId=@Route', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRoutePicturesByRouteId @RouteId=@Route', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRoutes ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRoutes ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRoutes ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetShoeById @ShoeId=@Shoe;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetShoeById @ShoeId=@Shoe', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetShoeById @ShoeId=@Shoe', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllShoes ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllShoes ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllShoes ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetCurrentBikePart @BikeId=@Bike, @PartTypeId=@PartType;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetCurrentBikePart @BikeId=@Bike, @PartTypeId=@PartType', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetCurrentBikePart @BikeId=@Bike, @PartTypeId=@PartType', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetCurrentBikePartsById @BikeId=0;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetCurrentBikePartsById @BikeId=0', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetCurrentBikePartsById @BikeId=0', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetCurrentBikePartsById @BikeId=@Bike;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetCurrentBikePartsById @BikeId=@Bike', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetCurrentBikePartsById @BikeId=@Bike', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetPartAge @BikeId=@Bike, @PartTypeId=@PartType;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetPartAge @BikeId=@Bike, @PartTypeId=@PartType', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetPartAge @BikeId=@Bike, @PartTypeId=@PartType', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetMaintenanceByBikeId @BikeId=@Bike;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetMaintenanceByBikeId @BikeId=@Bike', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetMaintenanceByBikeId @BikeId=@Bike', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetMaintenanceSubset @BikeId=@Bike, @StartIndex=1, @NumberOfRecords=10;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetMaintenanceSubset @BikeId=@Bike, @StartIndex=1, @NumberOfRecords=10', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetMaintenanceSubset @BikeId=@Bike, @StartIndex=1, @NumberOfRecords=10', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetLastEntries ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetLastEntries ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetLastEntries ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetWeightReadingsByDate @StartDate=@S, @EndDate=@E;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetWeightReadingsByDate @StartDate=@S, @EndDate=@E', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetWeightReadingsByDate @StartDate=@S, @EndDate=@E', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetWeightReadingsByDate ;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetWeightReadingsByDate ', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetWeightReadingsByDate ', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetWindDistribution @StartDate=@S, @EndDate=@E;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetWindDistribution @StartDate=@S, @EndDate=@E', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetWindDistribution @StartDate=@S, @EndDate=@E', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=1;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=1', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=1', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=2;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetStationaryRideDistribution @StartDate=@S, @EndDate=@E, @Type=2;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetStationaryRideDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetStationaryRideDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRunDistribution @StartDate=@S, @EndDate=@E, @Type=2;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetRunDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetRunDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetWalkDistribution @StartDate=@S, @EndDate=@E, @Type=1;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetWalkDistribution @StartDate=@S, @EndDate=@E, @Type=1', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetWalkDistribution @StartDate=@S, @EndDate=@E, @Type=1', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetTreadmillRunDistribution @StartDate=@S, @EndDate=@E, @Type=2;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: GetTreadmillRunDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: GetTreadmillRunDistribution @StartDate=@S, @EndDate=@E, @Type=2', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByType @RideType=1;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByType @RideType=1', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByType @RideType=1', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByType @RideType=2;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByType @RideType=2', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByType @RideType=2', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByTypeByDate @RideType=1, @StartDate=@S, @EndDate=@E;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByTypeByDate @RideType=1, @StartDate=@S, @EndDate=@E', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByTypeByDate @RideType=1, @StartDate=@S, @EndDate=@E', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByTypeById @RideType=1, @Id=@TrainingRide;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=1, @Id=@TrainingRide', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=1, @Id=@TrainingRide', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByTypeById @RideType=2, @Id=@RecRide;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=2, @Id=@RecRide', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=2, @Id=@RecRide', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByTypeById @RideType=3, @Id=@StatRide;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=3, @Id=@StatRide', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=3, @Id=@StatRide', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRidesByTypeById @RideType=3, @Id=@StatRideNoBike;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=3, @Id=@StatRideNoBike', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRidesByTypeById @RideType=3, @Id=@StatRideNoBike', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRunsByTypeById @RunType=1, @Id=@TrainingRun;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRunsByTypeById @RunType=1, @Id=@TrainingRun', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRunsByTypeById @RunType=1, @Id=@TrainingRun', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllRunsByTypeById @RunType=3, @Id=@Treadmill;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllRunsByTypeById @RunType=3, @Id=@Treadmill', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllRunsByTypeById @RunType=3, @Id=@Treadmill', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllWalksByTypeById @WalkType=1, @Id=@TrainingWalk;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectAllWalksByTypeById @WalkType=1, @Id=@TrainingWalk', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectAllWalksByTypeById @WalkType=1, @Id=@TrainingWalk', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectGPXByTypeById @Type=1, @Id=@TrainingRide;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome) VALUES (N'smoke: SelectGPXByTypeById @Type=1, @Id=@TrainingRide', 'OK');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'smoke: SelectGPXByTypeById @Type=1, @Id=@TrainingRide', 'FAIL', LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectGPXByTypeById @Type=NULL, @Id=1;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50006: SelectGPXByTypeById @Type=NULL, @Id=1', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50006: SelectGPXByTypeById @Type=NULL, @Id=1', CASE WHEN ERROR_NUMBER() = 50006 THEN 'OK' ELSE 'FAIL' END, LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectGPXByTypeById @Type=3, @Id=1;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50006: SelectGPXByTypeById @Type=3, @Id=1', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50006: SelectGPXByTypeById @Type=3, @Id=1', CASE WHEN ERROR_NUMBER() = 50006 THEN 'OK' ELSE 'FAIL' END, LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=9;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50008: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=9', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50008: GetRideDistribution @StartDate=@S, @EndDate=@E, @Type=9', CASE WHEN ERROR_NUMBER() = 50008 THEN 'OK' ELSE 'FAIL' END, LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.SelectAllPartsSubset @StartIndex=0, @NumberOfRecords=10;'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50005: SelectAllPartsSubset @StartIndex=0, @NumberOfRecords=10', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50005: SelectAllPartsSubset @StartIndex=0, @NumberOfRecords=10', CASE WHEN ERROR_NUMBER() = 50005 THEN 'OK' ELSE 'FAIL' END, LEFT(ERROR_MESSAGE(), 400));
END CATCH;
BEGIN TRY
    SET @sql = N'EXEC fixtest.GetMissedMilesByDateByType @TypeName=N''no such type'';'; EXEC sp_executesql @sql, @params, @S, @E, @OneDay, @Yr, @Bike, @Shoe, @ExType, @BikeName, @Circuit, @CircuitComponent, @Manufacturer, @Part, @PartType, @PartTypeName, @Route, @TrainingRide, @RecRide, @StatRide, @StatRideNoBike, @TrainingRun, @Treadmill, @TrainingWalk;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50003: GetMissedMilesByDateByType @TypeName=N''no such type''', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50003: GetMissedMilesByDateByType @TypeName=N''no such type''', CASE WHEN ERROR_NUMBER() = 50003 THEN 'OK' ELSE 'FAIL' END, LEFT(ERROR_MESSAGE(), 400));
END CATCH;

-- Write tests. Every write runs inside a transaction that is rolled back. XACT_ABORT ON means a cancel or timeout
-- also rolls back. Each test (re)opens a transaction if a previous failure ended it.
SET XACT_ABORT ON;
PRINT N'--- Write tests (rolled back): the Id result sets below come from the fixed insert procedures ---';
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertTrainingRide @Date='2099-01-01', @StartOdometer=0, @EndOdometer=10, @StartTime='2099-01-01T12:00:00', @EndTime='2099-01-01T12:35:10', @AverageHR=140, @MaxHR=160, @AverageCadence=70, @ElevationGain=100, @MaxSpeed=20.5, @WindSpeed=5, @WindDirection=N'NW ', @Temperature=60, @Precipitation=0, @BikeId=@Bike, @RouteId=@Route, @Distance=10.2345;
    SET @id = (SELECT MAX(Id) FROM dbo.TrainingRide WHERE [Date] = '2099-01-01');
    IF COALESCE((SELECT CASE WHEN RideTimeHours = 0 AND RideTimeMinutes = 35 AND RideTimeSeconds = 10 AND WindDirection = N'NW' AND Distance = 10.2345 THEN 1 ELSE 0 END FROM dbo.TrainingRide WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertTrainingRide', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertTrainingRide', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertRecreationalRide @Date='2099-01-02', @StartOdometer=1, @EndOdometer=11, @StartTime='2099-01-02T08:00:00', @EndTime='2099-01-02T10:05:00', @BikeEndTime='2099-01-02T09:50:30', @AverageHR=130, @MaxHR=150, @AverageCadence=70, @ElevationGain=50, @MaxSpeed=18, @Wind=N'calm', @Temperature=55, @Precipitation=0, @BikeId=@Bike, @RouteId=@Route;
    SET @id = (SELECT MAX(Id) FROM dbo.RecreationalRide WHERE [Date] = '2099-01-02');
    IF COALESCE((SELECT CASE WHEN RideTimeHours = 2 AND RideTimeMinutes = 5 AND BikeTimeHours = 1 AND BikeTimeMinutes = 50 AND BikeTimeSeconds = 30 THEN 1 ELSE 0 END FROM dbo.RecreationalRide WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertRecreationalRide', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertRecreationalRide', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertStationaryRide @Date='2099-01-03', @StartOdometer=0, @EndOdometer=10, @StartTime='2099-01-03T06:00:00', @EndTime='2099-01-03T06:30:00', @AverageHR=120, @MaxHR=140, @AverageCadence=80;
    SET @id = (SELECT MAX(Id) FROM dbo.StationaryRide WHERE [Date] = '2099-01-03');
    IF COALESCE((SELECT CASE WHEN BikeId IS NULL AND RideTimeMinutes = 30 THEN 1 ELSE 0 END FROM dbo.StationaryRide WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertStationaryRide', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertStationaryRide', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertTrainingRun @Date='2099-01-04', @Distance=3.1, @StartTime='2099-01-04T07:00:00', @EndTime='2099-01-04T07:28:00', @AverageHR=150, @MaxHR=170, @ElevationGain=20, @MaxSpeed=8.25, @WindSpeed=3, @WindDirection=N'S', @Temperature=50, @Precipitation=0, @ShoeId=@Shoe, @RouteId=@Route;
    SET @id = (SELECT MAX(Id) FROM dbo.TrainingRun WHERE [Date] = '2099-01-04');
    IF COALESCE((SELECT CASE WHEN Distance = 3.1 AND MaxSpeed = 8.25 AND RunTimeMinutes = 28 THEN 1 ELSE 0 END FROM dbo.TrainingRun WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertTrainingRun', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertTrainingRun', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertTrainingWalk @Date='2099-01-05', @Distance=2.5, @StartTime='2099-01-05T07:00:00', @EndTime='2099-01-05T07:50:00', @AverageHR=100, @MaxHR=120, @ElevationGain=10, @MaxSpeed=3.5, @WindSpeed=2, @WindDirection=N'N', @Temperature=50, @Precipitation=0, @ShoeId=@Shoe, @RouteId=@Route;
    SET @id = (SELECT MAX(Id) FROM dbo.TrainingWalk WHERE [Date] = '2099-01-05');
    IF COALESCE((SELECT CASE WHEN WalkTimeMinutes = 50 THEN 1 ELSE 0 END FROM dbo.TrainingWalk WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertTrainingWalk', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertTrainingWalk', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertMissedMilesByType @Date='2099-01-06', @Miles=2.75, @TypeName=@ExType;
    SET @id = (SELECT MAX(Id) FROM dbo.MissedMiles WHERE [Date] = '2099-01-06' AND Miles = 2.75);
    IF COALESCE((SELECT CASE WHEN Miles = 2.75 THEN 1 ELSE 0 END FROM dbo.MissedMiles WHERE Id = @id), 0) <> 1 SET @msg = N'row inserted but stored values were not as expected';
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertMissedMilesByType', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertMissedMilesByType', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertMissedMiles @Date='2099-01-06', @Miles=1.25, @Type=@ExTypeId;
    SET @id = (SELECT MAX(Id) FROM dbo.MissedMiles WHERE [Date] = '2099-01-06' AND Miles = 1.25);
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertMissedMiles', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertMissedMiles', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertRoute @Name=N'zz fixtest route', @City=N'Kent', @State='WA', @TypeId=@RouteType, @Rating=3;
    SET @id = (SELECT MAX(Id) FROM dbo.[Route] WHERE [Name] = N'zz fixtest route');
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertRoute', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertRoute', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertWeightReading @Date='2099-01-07', @Weight=180.5, @BodyFatPercentage=18.25;
    SET @id = (SELECT MAX(Id) FROM dbo.[Weight] WHERE [Date] = '2099-01-07');
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertWeightReading', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertWeightReading', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertTrainingRideGPX @TrainingRideId=@TrainingRide, @GPX=N'<gpx>fixtest</gpx>';
    SET @id = (SELECT MAX(Id) FROM dbo.TrainingRideGPX WHERE TrainingRideId = @TrainingRide AND CAST(GPX AS nvarchar(100)) = N'<gpx>fixtest</gpx>');
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertTrainingRideGPX', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertTrainingRideGPX', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertBikeOnlyMiles @Date='2099-01-08', @StartOdometer=0, @EndOdometer=5, @BikeId=@Bike;
    SET @id = (SELECT MAX(Id) FROM dbo.BikeOnlyMiles WHERE [Date] = '2099-01-08');
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertBikeOnlyMiles', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertBikeOnlyMiles', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    SELECT @id = NULL, @msg = NULL;
    EXEC fixtest.InsertLiftingSession @Date='2099-01-09', @CircuitId=@Lift, @NumberOfSets=3;
    SET @id = (SELECT MAX(Id) FROM dbo.LiftingSession WHERE [Date] = '2099-01-09');
    INSERT @Results (Test, Outcome, Fixed, Note)
    VALUES (N'write: InsertLiftingSession', CASE WHEN @id IS NULL OR @msg IS NOT NULL THEN 'FAIL' ELSE 'OK' END, CONCAT(N'Id=', @id), COALESCE(@msg, CASE WHEN @id IS NULL THEN N'no row found' END));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: InsertLiftingSession', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    EXEC fixtest.InsertTrainingRide @Date='2099-01-01', @StartOdometer=0, @EndOdometer=10, @StartTime='2099-01-01T12:00:00', @EndTime='2099-01-01T11:00:00',
         @AverageHR=140, @MaxHR=160, @AverageCadence=70, @ElevationGain=0, @MaxSpeed=20, @WindSpeed=5, @WindDirection=N'N', @Temperature=60,
         @Precipitation=0, @BikeId=@Bike, @RouteId=@Route;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50001: InsertTrainingRide with EndTime < StartTime', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50001: InsertTrainingRide with EndTime < StartTime',
        CASE WHEN @err = 50001 OR @msg LIKE N'%must not be earlier%' THEN 'OK' ELSE 'FAIL' END, @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @before int = (SELECT BaseMiles FROM dbo.Bike WHERE Id = @Bike), @after int;
    EXEC fixtest.UpdateBaseMiles @BikeId = @Bike, @Miles = 7;
    SET @after = (SELECT BaseMiles FROM dbo.Bike WHERE Id = @Bike);
    INSERT @Results (Test, Outcome, Original, Fixed)
    VALUES (N'write: UpdateBaseMiles +7', CASE WHEN @after = @before + 7 THEN 'OK' ELSE 'FAIL' END, CONCAT(N'before=', @before), CONCAT(N'after=', @after));
END TRY BEGIN CATCH
    SET @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'write: UpdateBaseMiles +7', 'FAIL', @msg);
END CATCH;
IF @@TRANCOUNT = 0 BEGIN TRANSACTION;
BEGIN TRY
    EXEC fixtest.UpdateBaseMiles @BikeId = -1, @Miles = 1;
    INSERT @Results (Test, Outcome, Note) VALUES (N'expect error 50010: UpdateBaseMiles on a missing bike', 'FAIL', N'no error raised');
END TRY BEGIN CATCH
    SELECT @err = ERROR_NUMBER(), @msg = LEFT(ERROR_MESSAGE(), 400);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT @Results (Test, Outcome, Fixed) VALUES (N'expect error 50010: UpdateBaseMiles on a missing bike',
        CASE WHEN @err = 50010 OR @msg LIKE N'%Bike not found%' THEN 'OK' ELSE 'FAIL' END, @msg);
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;   -- undo every write test
SET XACT_ABORT OFF;

PRINT N'';
PRINT N'=============================== SUMMARY ===============================';
SELECT Outcome, COUNT(*) AS Tests FROM @Results GROUP BY Outcome ORDER BY Outcome;
SELECT Seq, Outcome, Test, Original, Fixed, Note FROM @Results
ORDER BY CASE Outcome WHEN 'FIXED-ERROR' THEN 1 WHEN 'UNEXPECTED-DIFF' THEN 2 WHEN 'FAIL' THEN 3 WHEN 'ORIG-ERROR' THEN 4 WHEN 'EXPECTED-DIFF' THEN 5 ELSE 6 END, Seq;
GO
-- Safety net: if Part 2 stopped part-way, make sure no test transaction is left open.
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

-- ---------- Part 3: remove the scratch objects ----------
DECLARE @drop nvarchar(max) = N'';
SELECT @drop += N'DROP ' + CASE o.type WHEN 'P' THEN N'PROCEDURE ' ELSE N'FUNCTION ' END + N'fixtest.' + QUOTENAME(o.name) + N';' + NCHAR(10)
FROM sys.objects AS o WHERE o.schema_id = SCHEMA_ID(N'fixtest') AND o.type IN ('P', 'FN');
EXEC sys.sp_executesql @drop;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'fixtest')) EXEC (N'DROP SCHEMA fixtest');
GO
SET NOEXEC OFF;
GO
