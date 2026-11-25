
-- dbo.GetMaxOdometerByBike
-- Changes:
--   * Logic unchanged (despite the name it sums logged miles from all five odometer sources for the bike).
--   * One SELECT; result column named TotalLoggedMiles; schema-qualified.
CREATE   PROCEDURE dbo.GetMaxOdometerByBike
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

