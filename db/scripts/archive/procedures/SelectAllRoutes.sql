-- Fixed version of dbo.SelectAllRoutes (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllRoutes.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllRoutes
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; ORDER BY Name; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllRoutes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.Id,
           r.[Name],
           r.City,
           r.[State],
           r.TypeId,
           rt.[Name]                                   AS TypeName,
           r.Rating,
           COALESCE(CAST(r.Notes AS varchar(max)), '') AS Notes
    FROM dbo.[Route] AS r
    INNER JOIN dbo.RouteType AS rt ON rt.Id = r.TypeId
    ORDER BY r.[Name];
END;
GO
