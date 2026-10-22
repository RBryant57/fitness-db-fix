-- Fixed version of dbo.SelectAllManufacturers (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllManufacturers.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllManufacturers
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllManufacturers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name]
    FROM dbo.Manufacturer AS m
    ORDER BY m.[Name];
END;
GO
