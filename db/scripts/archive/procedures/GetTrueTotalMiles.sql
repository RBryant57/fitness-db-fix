-- Fixed version of dbo.GetTrueTotalMiles (2026-10-14). The pre-fix original is archive/procedures-original/GetTrueTotalMiles.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetTrueTotalMiles
-- Changes:
--   * Logic unchanged (training + recreational odometer miles + every bike's BaseMiles); one SELECT, column TotalMiles.
CREATE OR ALTER PROCEDURE dbo.GetTrueTotalMiles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.TrainingRide     AS x), 0)
        + COALESCE((SELECT SUM(x.EndOdometer - x.StartOdometer) FROM dbo.RecreationalRide AS x), 0)
        + COALESCE((SELECT SUM(b.BaseMiles)                     FROM dbo.Bike             AS b), 0)
        AS TotalMiles;
END;
GO
