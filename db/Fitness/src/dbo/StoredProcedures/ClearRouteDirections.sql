




-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 7/28/06
-- Description:	Removes the directions from a Route
-- =============================================
CREATE PROCEDURE [dbo].[ClearRouteDirections]
	
	@Id						int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE FROM
		RouteDirection
	WHERE
		RouteId = @Id

END

GO

