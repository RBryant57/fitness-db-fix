-- Fixed version of dbo.GetAverageGymHours (2026-10-14). The pre-fix original is archive/procedures-original/GetAverageGymHours.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetAverageGymHours
-- Changes:
--   * BUG: divide-by-zero when @StartDate = @EndDate (weeks = 0, then days/7 = 0). A single-day range now counts as 1/7 week.
--   * Estimates and the weeks divisor are otherwise unchanged (DATEDIFF(week), falling back to days/7).
--   * Range parameters are `date`, end date inclusive; result column named AverageWeeklyHours (float, as before).
CREATE OR ALTER PROCEDURE dbo.GetAverageGymHours
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);
    DECLARE @Weeks float = DATEDIFF(week, @StartDate, @EndDate);

    IF @Weeks = 0
        SET @Weeks = DATEDIFF(day, @StartDate, @EndDate) / 7.0;
    IF @Weeks <= 0
        SET @Weeks = 1 / 7.0;

    SELECT CAST((
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.StationaryRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 20.0
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TrainingRun    AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TreadmillRun   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 7.6
        + COALESCE((SELECT SUM(x.NumberOfSets)                   FROM dbo.LiftingSession AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 8.0
        + COALESCE((SELECT SUM(x.StairQuantity)                  FROM dbo.Stairs         AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / 2400.0
        ) / @Weeks AS float) AS AverageWeeklyHours;
END;
GO
