-- Fixed version of dbo.GetMaxOdometerByBike (2026-10-14). The pre-fix original is archive/procedures-original/GetMaxOdometerByBike.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMaxOdometerByBike
-- Changes:
--   * Logic unchanged (despite the name it sums logged miles from all five odometer sources for the bike).
--   * One SELECT; result column named TotalLoggedMiles; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetMaxOdometerByBike
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
