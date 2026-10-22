



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/23/06
-- Description:	Retrieves the display description 
--				for a Route from the given Route Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetRouteDescriptionByRouteId]
	 
	@RouteId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Description
	FROM RouteDisplay
			
	WHERE
		RouteId = @RouteId

END

GO

