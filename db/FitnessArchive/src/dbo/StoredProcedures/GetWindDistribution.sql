
-- dbo.GetWindDistribution
-- Changes:
--   * BUG: UNION ALL of two GROUP BYs returned each direction twice (once for rides, once for runs). Now one row per
--     direction with the combined count.
--   * WindDirection returned trimmed (186 stored values carry a trailing space, e.g. 'W '). Cosmetic only: SQL Server
--     already ignores trailing spaces when grouping, so this does not change the counts.
--   * Count column renamed Activities (it counts activities, not days); ordered by direction.
CREATE   PROCEDURE dbo.GetWindDistribution
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT RTRIM(a.WindDirection) AS WindDirection,
           COUNT(*)               AS Activities
    FROM (
        SELECT x.WindDirection FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.WindDirection FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a
    GROUP BY RTRIM(a.WindDirection)
    ORDER BY RTRIM(a.WindDirection);
END;

GO

