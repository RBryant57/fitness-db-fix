
-- dbo.GetRouteDescriptionByRouteId
-- Changes:
--   * text Description cast to varchar(max); schema-qualified.
CREATE   PROCEDURE dbo.GetRouteDescriptionByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(rd.[Description] AS varchar(max)) AS [Description]
    FROM dbo.RouteDisplay AS rd
    WHERE rd.RouteId = @RouteId;
END;

GO

