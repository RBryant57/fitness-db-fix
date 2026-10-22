-- Fixed version of dbo.GetPartTypeByName (2026-10-14). The pre-fix original is archive/procedures-original/GetPartTypeByName.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetPartTypeByName
-- Changes:
--   * Schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetPartTypeByName
    @PartTypeName nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    WHERE pt.[Name] = @PartTypeName;
END;
GO
