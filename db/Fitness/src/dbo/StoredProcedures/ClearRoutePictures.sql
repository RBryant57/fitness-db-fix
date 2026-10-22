



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/25/06
-- Description:	Removes the pictures from a Route
-- =============================================
CREATE PROCEDURE [dbo].[ClearRoutePictures]
	
	@RouteId						int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE FROM
		RoutePicture
	WHERE
		RouteId = @RouteId

END

GO

