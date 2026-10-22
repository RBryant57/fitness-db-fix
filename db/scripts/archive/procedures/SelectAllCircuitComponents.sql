-- Fixed version of dbo.SelectAllCircuitComponents (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllCircuitComponents.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllCircuitComponents
-- Changes:
--   * Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY ExerciseName; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllCircuitComponents
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cc.Id,
           cc.ExerciseName,
           COALESCE(CAST(cc.Notes AS nvarchar(max)), N'') AS Notes
    FROM dbo.CircuitComponent AS cc
    ORDER BY cc.ExerciseName;
END;
GO
