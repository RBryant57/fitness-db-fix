
-- dbo.GetTotalGymHours
-- Changes:
--   * Estimates kept exactly as before (by request): ride miles / 20, run miles / 7.6, sets / 8, stairs / 2400.
--   * Six SET statements collapsed into one SELECT; range parameters are `date`, end date inclusive.
--   * Result column named TotalHours (float, as before); schema-qualified.
CREATE   PROCEDURE dbo.GetTotalGymHours
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

