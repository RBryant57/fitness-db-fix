
-- dbo.GetRouteById
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; schema-qualified.
CREATE   PROCEDURE dbo.GetRouteById
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

