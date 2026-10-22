-- Fixed version of dbo.GetPartTypeById (2026-10-14). The pre-fix original is archive/procedures-original/GetPartTypeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetPartTypeById
-- Changes:
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetPartTypeById
    @PartTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.Id = @PartTypeId;
END;
GO
