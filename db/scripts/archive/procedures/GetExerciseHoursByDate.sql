-- Fixed version of dbo.GetExerciseHoursByDate (2026-10-14). The pre-fix original is archive/procedures-original/GetExerciseHoursByDate.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetExerciseHoursByDate
-- Changes:
--   * BUG: @LiftDivisor was int, so SUM(NumberOfSets) / @LiftDivisor was integer division (truncated). Now decimal.
--   * Zero, negative or NULL divisors raise an error instead of a divide-by-zero.
--   * SET NOCOUNT and the DECLAREs sat outside BEGIN...END; restructured.
--   * Range parameters are `date`, end date inclusive; result column named ExerciseHours.
CREATE OR ALTER PROCEDURE dbo.GetExerciseHoursByDate
    @StartDate   date,
    @EndDate     date,
    @RideDivisor decimal(18,2),
    @RunDivisor  decimal(18,2),
    @LiftDivisor decimal(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@RideDivisor, 0) <= 0 OR COALESCE(@RunDivisor, 0) <= 0 OR COALESCE(@LiftDivisor, 0) <= 0
        THROW 50007, N'Divisors must be greater than zero.', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

    -- Each component is rounded to decimal(18,2) before summing, exactly as the original's decimal(18,2) variables did.
    SELECT
          CAST(COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide   AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @RideDivisor AS decimal(18,2))
        + CAST(COALESCE((SELECT SUM(x.Distance)                       FROM dbo.TrainingRun    AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @RunDivisor  AS decimal(18,2))
        + CAST(COALESCE((SELECT SUM(x.NumberOfSets)                   FROM dbo.LiftingSession AS x WHERE x.[Date] >= @StartDate AND x.[Date] < @EndExclusive), 0) / @LiftDivisor AS decimal(18,2))
        AS ExerciseHours;
END;
GO
