-- Fixed version of dbo.GetMilesByDateByBikeByRideType (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByDateByBikeByRideType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByDateByBikeByRideType
-- Changes:
--   * Five IF blocks replaced by one SELECT with CASE per source; unknown @RideType raises an error; clamp at 0 kept.
--   * NULL @StartDate / @EndDate now mean "open-ended" (previously a NULL produced 0); end date inclusive.
--   * Result column named Miles. Ride types as in GetMilesByBikeByRideType.
CREATE OR ALTER PROCEDURE dbo.GetMilesByDateByBikeByRideType
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
