-- Fixed version of dbo.GetMilesByDateByRideType (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByDateByRideType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByDateByRideType
-- Changes:
--   * Four IF blocks (each with its own NULL-date branch) replaced by one SELECT; unknown @RideType raises an error;
--     clamp at 0 kept. @StartDate and @EndDate are independently optional; end date inclusive.
--   * Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + trainer (with a bike),
--     4 trainer (with a bike).
CREATE OR ALTER PROCEDURE dbo.GetMilesByDateByRideType
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
