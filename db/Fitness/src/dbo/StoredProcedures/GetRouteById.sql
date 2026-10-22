





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/29/06
-- Description:	Retrieves a Route from the given Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetRouteById]
	 
	@RouteId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT [Route].Id, [Name], City, State, Rating, TypeId, Notes
	FROM [Route]
			
	WHERE
		[Route].Id = @RouteId

END

GO

