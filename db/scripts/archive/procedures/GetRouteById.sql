-- Fixed version of dbo.GetRouteById (2026-10-14). The pre-fix original is archive/procedures-original/GetRouteById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRouteById
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetRouteById
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.Id,
           r.[Name],
           r.City,
           r.[State],
           r.Rating,
           r.TypeId,
           COALESCE(CAST(r.Notes AS varchar(max)), '') AS Notes
    FROM dbo.[Route] AS r
    WHERE r.Id = @RouteId;
END;
GO
