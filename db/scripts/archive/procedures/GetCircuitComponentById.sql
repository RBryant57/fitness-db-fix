-- Fixed version of dbo.GetCircuitComponentById (2026-10-14). The pre-fix original is archive/procedures-original/GetCircuitComponentById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetCircuitComponentById
-- Changes:
--   * ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetCircuitComponentById
    @CircuitComponentId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    WHERE cc.Id = @CircuitComponentId;
END;
GO
