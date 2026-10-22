



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/26/2006
-- Description:	This stored procedure will select
--				the route directions for a given
--				Route Id number.
-- =============================================
CREATE PROCEDURE [dbo].[GetRouteDirectionsByRouteId]

	@RouteId			int
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
			Id,
			RouteId,
			DirectionNumber,
			DirectionMileMarker,
			DirectionDescription,
			CAST(DirectionMileMarker AS nvarchar) + ': ' + 
			DirectionDescription AS DirectionStep
	FROM RouteDirection
	WHERE
		RouteId = @RouteId
	ORDER BY DirectionNumber

END

GO

