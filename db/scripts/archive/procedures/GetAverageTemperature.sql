-- Fixed version of dbo.GetAverageTemperature (2026-10-14). The pre-fix original is archive/procedures-original/GetAverageTemperature.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetAverageTemperature
-- Changes:
--   * Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
--   * Range parameters are `date`, end date inclusive; result column named AverageTemperature.
CREATE OR ALTER PROCEDURE dbo.GetAverageTemperature
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    SELECT COALESCE(AVG(CAST(a.Temperature AS float)), 0) AS AverageTemperature
    FROM (
        SELECT x.Temperature FROM dbo.TrainingRide AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        UNION ALL
        SELECT x.Temperature FROM dbo.TrainingRun  AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
    ) AS a;
END;
GO
