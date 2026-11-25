
-- dbo.GetTrueTotalMiles
-- Changes:
--   * Logic unchanged (training + recreational odometer miles + every bike's BaseMiles); one SELECT, column TotalMiles.
CREATE   PROCEDURE dbo.GetTrueTotalMiles
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

