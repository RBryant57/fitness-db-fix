



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/24/2006
-- Description:	This stored procedure will select
--				the pictures for a given
--				Route Id number.
-- =============================================
CREATE PROCEDURE [dbo].[GetRoutePicturesByRouteId]

	@RouteId			int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
			Id,
			RouteId,
			ImageFileName,
			ImageDescription
	FROM RoutePicture
	WHERE
		RouteId = @RouteId

END

GO

