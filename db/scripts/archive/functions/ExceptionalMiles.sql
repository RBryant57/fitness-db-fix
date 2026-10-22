-- Fixed version of dbo.ExceptionalMiles (2026-10-14). The pre-fix original is archive/functions-original/ExceptionalMiles.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.ExceptionalMiles
-- Changes:
--   * BUG: the "all bikes, date range" branch tested `@StartDate <> null`, which is never true, so it
--     always returned the all-time total. Replaced the four branches with one query using IS NULL logic.
--   * Date parameters are now `date`; the range is inclusive of the whole @EndDate day.
--   * Schema-qualified.
CREATE OR ALTER FUNCTION dbo.ExceptionalMiles
(
    @StartDate date,
    @EndDate   date,
    @BikeId    int
)
RETURNS int
AS
BEGIN
    RETURN COALESCE((
        SELECT SUM(bom.EndOdometer - bom.StartOdometer)
        FROM dbo.BikeOnlyMiles AS bom
        WHERE (@BikeId IS NULL OR @BikeId <= 0 OR bom.BikeId = @BikeId)
          AND (@StartDate IS NULL
               OR (bom.[Date] >= @StartDate AND bom.[Date] < DATEADD(day, 1, @EndDate)))
    ), 0);
END;
GO
