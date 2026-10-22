-- Fixed version of dbo.ToDecimalHours (2026-10-14). The pre-fix original is archive/functions-original/ToDecimalHours.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.ToDecimalHours
-- Changes:
--   * BUG: `RETURNS decimal` with no scale is decimal(18,0), so 1 h 30 m returned 2 instead of 1.5.
--     Now returns decimal(9,4).
CREATE OR ALTER FUNCTION dbo.ToDecimalHours
(
    @Hours   int,
    @Minutes int
)
RETURNS decimal(9,4)
AS
BEGIN
    RETURN CAST(@Hours AS decimal(9,4)) + CAST(@Minutes AS decimal(9,4)) / 60.0;
END;
GO
