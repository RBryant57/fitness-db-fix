-- Fixed version of dbo.GetRoutePicturesByRouteId (2026-10-14). The pre-fix original is archive/procedures-original/GetRoutePicturesByRouteId.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetRoutePicturesByRouteId
-- Changes:
--   * text ImageDescription cast to varchar(max); ORDER BY Id; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetRoutePicturesByRouteId
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
