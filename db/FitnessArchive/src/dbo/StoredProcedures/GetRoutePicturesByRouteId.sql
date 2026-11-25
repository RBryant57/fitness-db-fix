
-- dbo.GetRoutePicturesByRouteId
-- Changes:
--   * text ImageDescription cast to varchar(max); ORDER BY Id; schema-qualified.
CREATE   PROCEDURE dbo.GetRoutePicturesByRouteId
    @RouteId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rp.Id,
           rp.RouteId,
           rp.ImageFileName,
           CAST(rp.ImageDescription AS varchar(max)) AS ImageDescription
    FROM dbo.RoutePicture AS rp
    WHERE rp.RouteId = @RouteId
    ORDER BY rp.Id;
END;

GO

