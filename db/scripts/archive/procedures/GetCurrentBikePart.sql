-- Fixed version of dbo.GetCurrentBikePart (2026-10-14). The pre-fix original is archive/procedures-original/GetCurrentBikePart.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetCurrentBikePart
-- Changes:
--   * The same three-table join was written twice (outer query + MIN subquery). Rewritten as TOP (1) WITH TIES,
--     which returns exactly the same rows. The PartType join is no longer needed (filter on Part.PartTypeId).
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetCurrentBikePart
    @BikeId     int,
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1) WITH TIES
           bp.Id,
           bp.PartId
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part AS p ON p.Id = bp.PartId
    WHERE bp.BikeId     = @BikeId
      AND p.PartTypeId  = @PartTypeId
      AND bp.EndDate IS NULL
    ORDER BY bp.OdometerReading;
END;
GO
