-- Fixed version of dbo.GetRainDays (2026-10-14). The pre-fix original is archive/procedures-original/GetRainDays.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRainDays
-- Changes:
--   * bit column compared to 1 instead of the string 'True'.
--   * Range parameters are `date`, end date inclusive; result column named RainActivities (it counts activities, not days).
CREATE OR ALTER PROCEDURE dbo.GetRainDays
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
