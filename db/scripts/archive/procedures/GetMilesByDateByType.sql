-- Fixed version of dbo.GetMilesByDateByType (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByDateByType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByDateByType
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
CREATE OR ALTER PROCEDURE dbo.GetMilesByDateByType
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
