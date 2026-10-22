-- Fixed version of dbo.GetRouteDirectionsByRouteId (2026-10-14). The pre-fix original is archive/procedures-original/GetRouteDirectionsByRouteId.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRouteDirectionsByRouteId
-- Changes:
--   * CAST(... AS nvarchar) without a length replaced by an explicit length; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetRouteDirectionsByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rd.Id,
           rd.RouteId,
           rd.DirectionNumber,
           rd.DirectionMileMarker,
           rd.DirectionDescription,
           CONCAT(CAST(rd.DirectionMileMarker AS nvarchar(20)), N': ', rd.DirectionDescription) AS DirectionStep
    FROM dbo.RouteDirection AS rd
    WHERE rd.RouteId = @RouteId
    ORDER BY rd.DirectionNumber;
END;
GO
