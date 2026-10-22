-- Fixed version of dbo.GetMaintenanceCount (2026-10-14). The pre-fix original is archive/procedures-original/GetMaintenanceCount.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMaintenanceCount
-- Changes:
--   * Result column named MaintenanceCount; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetMaintenanceCount
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS MaintenanceCount
    FROM dbo.Maintenance AS mt
    WHERE mt.BikeId = @BikeId;
END;
GO
