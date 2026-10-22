-- Fixed version of dbo.SelectAllRidesByType (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllRidesByType.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllRidesByType
-- Changes:
--   * Was a copy of SelectAllRidesByTypeByDate without the WHERE clause (3,600 characters duplicated, and the two had
--     already drifted: one returned Notes raw, the other coalesced). Now delegates to SelectAllRidesByTypeByDate with
--     no date limits, so both return exactly the same columns. See that procedure for the column changes.
CREATE OR ALTER PROCEDURE dbo.SelectAllRidesByType
    @RideType int
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.SelectAllRidesByTypeByDate @RideType = @RideType, @StartDate = NULL, @EndDate = NULL;
END;
GO
