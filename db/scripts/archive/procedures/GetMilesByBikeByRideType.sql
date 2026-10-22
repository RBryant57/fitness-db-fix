-- Fixed version of dbo.GetMilesByBikeByRideType (2026-10-14). The pre-fix original is archive/procedures-original/GetMilesByBikeByRideType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMilesByBikeByRideType
-- Changes:
--   * Five IF blocks replaced by one SELECT with CASE per source; an unknown @RideType raises an error
--     (previously returned 0 after adding three NULLs).
--   * Kept: the result is clamped at 0 (StationaryRide has no End > Start constraint, so trainer sums can be negative).
--   * Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + this bike's trainer,
--     4 this bike's trainer, 5 trainer rides with no bike (ignores @BikeId).
CREATE OR ALTER PROCEDURE dbo.GetMilesByBikeByRideType
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
