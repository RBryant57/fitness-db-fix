



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/26/06
-- Description:	Inserts a Route direction.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRouteDirection]
	
	@RouteId				int,
	@DirectionNumber		int,
	@DirectionMileMarker	decimal(18, 2),
	@DirectionDescription	text

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RouteDirection
	VALUES(@RouteId, @DirectionNumber, 
		   @DirectionMileMarker, @DirectionDescription)

SELECT @@Identity

END

GO

