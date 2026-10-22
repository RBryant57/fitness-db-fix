-- Fixed version of dbo.GetRideDistribution (2026-10-14). The pre-fix original is archive/procedures-original/GetRideDistribution.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRideDistribution
-- Changes:
--   * BUG: grouped by MONTH(Date) only, so a multi-year range merged every January together. Now grouped by year and month.
--   * Column names without spaces: Year, MonthNumber, MonthName, Rides | Miles.
--   * An unknown @Type raises an error. Range parameters are `date`, end date inclusive.
CREATE OR ALTER PROCEDURE dbo.GetRideDistribution
    @StartDate date,
    @EndDate   date,
    @Type      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Type IS NULL OR @Type NOT IN (1, 2)
        THROW 50008, N'Type must be 1 (count) or 2 (miles).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    IF @Type = 1
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               COUNT(*) AS Rides
        FROM dbo.TrainingRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
    ELSE
        SELECT YEAR(x.[Date]) AS [Year], MONTH(x.[Date]) AS MonthNumber, DATENAME(month, x.[Date]) AS [MonthName],
               SUM(x.EndOdometer - x.StartOdometer) AS Miles
        FROM dbo.TrainingRide AS x
        WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive
        GROUP BY YEAR(x.[Date]), MONTH(x.[Date]), DATENAME(month, x.[Date])
        ORDER BY [Year], MonthNumber;
END;
GO
