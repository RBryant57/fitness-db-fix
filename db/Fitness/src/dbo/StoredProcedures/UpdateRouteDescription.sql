




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/23/06
-- Description:	Updates a Route description.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateRouteDescription]
	
	@RouteId				int,
	@Description			text

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    UPDATE
		RouteDisplay
	SET Description = @Description

	WHERE
		RouteId = @RouteId

END

GO

