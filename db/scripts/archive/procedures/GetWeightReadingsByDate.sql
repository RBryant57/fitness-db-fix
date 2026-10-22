-- Fixed version of dbo.GetWeightReadingsByDate (2026-10-14). The pre-fix original is archive/procedures-original/GetWeightReadingsByDate.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetWeightReadingsByDate
-- Changes:
--   * The NULL-defaulting IF statements sat outside BEGIN...END and before SET NOCOUNT ON. Restructured.
--   * NULL dates now mean "open-ended" directly in the WHERE clause (no extra MIN() lookup); end date is inclusive.
--   * Parameters are `date`; ORDER BY Date; Notes added; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetWeightReadingsByDate
    @StartDate date = NULL,
    @EndDate   date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT w.[Date],
           w.[Weight],
           w.BodyFatPercentage,
           COALESCE(CAST(w.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.[Weight] AS w
    WHERE (@StartDate IS NULL OR w.[Date] >= @StartDate)
      AND (@EndDate   IS NULL OR w.[Date] <  DATEADD(day, 1, @EndDate))
    ORDER BY w.[Date]
    OPTION (RECOMPILE);
END;
GO
