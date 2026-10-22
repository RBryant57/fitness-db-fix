



-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/12/06
-- Description:	Retrieves the number of maintenence logs in
--				the Maintenance table for the given Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetMaintenanceCount]

	@BikeId				int
	 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT COUNT(Id)
	FROM
		Maintenance
	WHERE
		BikeId = @BikeId

END

GO

