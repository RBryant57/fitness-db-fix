-- Fixed version of dbo.SelectAllCircuits (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllCircuits.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllCircuits
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllCircuits
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    ORDER BY c.[Name];
END;
GO
