-- Fixed version of dbo.SelectAllPartTypes (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllPartTypes.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllPartTypes
-- Changes:
--   * ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllPartTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pt.Id,
           pt.[Name]
    FROM dbo.PartType AS pt
    ORDER BY pt.[Name];
END;
GO
