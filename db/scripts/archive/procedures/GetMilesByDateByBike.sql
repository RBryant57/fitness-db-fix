-- Fixed version of dbo.GetMilesByDateByBike (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByDateByBike.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByDateByBike
-- Changes:
--   * BUG: miles in a range were OdometerReading(@EndDate) - OdometerReading(@StartDate). OdometerReading includes
--     everything dated <= its argument, so every ride ON @StartDate was excluded. The start reading is now the last
--     reading *before* @StartDate, or -- if the bike has no earlier reading -- the lowest StartOdometer inside the range.
--   * Bike-only and trainer miles subtracted with the same inclusive range (previously ExceptionalMiles + a BETWEEN).
--   * @StartDate and @EndDate are independently optional (both NULL = all-time, as before).
--   * The clamp to 0 is kept: an odometer replacement can make a range negative.
--   * Result column named Miles; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetMilesByDateByBike
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
