-- Fixed version of dbo.GetCircuitById (2026-10-14). The pre-fix original is archive/procedures-original/GetCircuitById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetCircuitById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetCircuitById
    @CircuitId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.Id,
           c.[Name],
           COALESCE(CAST(c.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.Circuit AS c
    WHERE c.Id = @CircuitId;
END;
GO
