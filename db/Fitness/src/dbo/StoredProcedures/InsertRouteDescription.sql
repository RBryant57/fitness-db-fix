



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 11/23/06
-- Description:	Inserts a Route description.
-- =============================================
CREATE PROCEDURE [dbo].[InsertRouteDescription]
	
	@RouteId				int,
	@Description			text

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    INSERT INTO
		RouteDisplay
	VALUES(@RouteId, @Description)

SELECT @@Identity

END

GO

