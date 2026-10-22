






-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 8/9/06
-- Description:	Retrieves all the maintenance actions
--				for the given Bike Id.
-- =============================================
CREATE PROCEDURE [dbo].[GetMaintenanceByBikeId]
	 
	@BikeId		int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT [Bike], [Operation Date], Bike, Manufacturer, Part, 
		   [Part Type], [Action Taken], Odometer, Notes
	FROM MaintenanceLog

	WHERE
		[Bike] = @BikeId
	ORDER BY Odometer

END

GO

