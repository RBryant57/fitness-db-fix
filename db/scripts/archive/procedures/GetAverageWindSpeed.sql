-- Fixed version of dbo.GetAverageWindSpeed (2026-10-14). The pre-fix original is archive/procedures-original/GetAverageWindSpeed.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetAverageWindSpeed
-- Changes:
--   * Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
--   * Range parameters are `date`, end date inclusive; result column named AverageWindSpeed.
CREATE OR ALTER PROCEDURE dbo.GetAverageWindSpeed
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(AVG(CAST(a.WindSpeed AS float)), 0) AS AverageWindSpeed
    FROM (
        SELECT x.WindSpeed FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.WindSpeed FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a;
END;
GO
