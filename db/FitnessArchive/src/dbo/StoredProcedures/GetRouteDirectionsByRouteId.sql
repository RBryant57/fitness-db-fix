
-- dbo.GetRouteDirectionsByRouteId
-- Changes:
--   * CAST(... AS nvarchar) without a length replaced by an explicit length; schema-qualified.
CREATE   PROCEDURE dbo.GetRouteDirectionsByRouteId
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

