
-- dbo.GetRainDays
-- Changes:
--   * bit column compared to 1 instead of the string 'True'.
--   * Range parameters are `date`, end date inclusive; result column named RainActivities (it counts activities, not days).
CREATE   PROCEDURE dbo.GetRainDays
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

