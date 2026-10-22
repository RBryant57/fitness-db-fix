-- Fixed version of dbo.GetTrainingMilesByYear (2026-10-14). The pre-fix original is archive/procedures-original/GetTrainingMilesByYear.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetTrainingMilesByYear
-- Changes:
--   * YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.
CREATE OR ALTER PROCEDURE dbo.GetTrainingMilesByYear
    @Year int = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Bounds computed up front: DATEFROMPARTS(0, 1, 1) would raise an error, and T-SQL does not guarantee
    -- short-circuit evaluation of OR, so the "all years" case must not reach DATEFROMPARTS.
    DECLARE @From date = CASE WHEN COALESCE(@Year, 0) = 0 THEN NULL ELSE DATEFROMPARTS(@Year, 1, 1) END;
    DECLARE @To   date = DATEADD(year, 1, @From);

    SELECT COALESCE(SUM(x.EndOdometer - x.StartOdometer), 0) AS Miles
    FROM dbo.TrainingRide AS x
    WHERE (@From IS NULL OR (x.[Date] >= @From AND x.[Date] < @To))
    OPTION (RECOMPILE);
END;
GO
