
-- dbo.SelectAllRoutes
-- Changes:
--   * text Notes cast to varchar(max), NULL returned as ''; ORDER BY Name; schema-qualified.
CREATE   PROCEDURE dbo.SelectAllRoutes
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

