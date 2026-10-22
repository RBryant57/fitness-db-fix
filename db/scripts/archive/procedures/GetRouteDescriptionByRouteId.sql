-- Fixed version of dbo.GetRouteDescriptionByRouteId (2026-10-14). The pre-fix original is archive/procedures-original/GetRouteDescriptionByRouteId.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRouteDescriptionByRouteId
-- Changes:
--   * text Description cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetRouteDescriptionByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(rd.[Description] AS varchar(max)) AS [Description]
    FROM dbo.RouteDisplay AS rd
    WHERE rd.RouteId = @RouteId;
END;
GO
