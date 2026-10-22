



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 5/29/2006
-- Description:	This stored procedure will select
--				all routes in the Route table
-- =============================================
CREATE PROCEDURE [dbo].[SelectAllRoutes]
	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
			[Route].Id,
			[Route].[Name],
			City,
			State,
			TypeId,
			[RouteType].[Name] AS TypeName,
			Rating,
			Notes
	FROM [Route]
		INNER JOIN [RouteType] ON
		[Route].TypeId = [RouteType].Id
END

GO

