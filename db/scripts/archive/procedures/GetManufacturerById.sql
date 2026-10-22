-- Fixed version of dbo.GetManufacturerById (2026-10-14). The pre-fix original is archive/procedures-original/GetManufacturerById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetManufacturerById
-- Changes:
--   * Notes added (cast from text); schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetManufacturerById
    @ManufacturerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.Id,
           m.[Name],
           COALESCE(CAST(m.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Manufacturer AS m
    WHERE m.Id = @ManufacturerId;
END;
GO
