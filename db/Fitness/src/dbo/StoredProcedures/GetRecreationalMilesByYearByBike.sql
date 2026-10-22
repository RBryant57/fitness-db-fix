





-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/6/06
-- Description:	This procedure will return the maximum
--				recreational odometer readings for the given year
--				and given Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetRecreationalMilesByYearByBike] 
		@Year					int = 0,
		@BikeId					int

AS
BEGIN

	SET NOCOUNT ON;

	IF @Year = 0
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM RecreationalRide
			WHERE BikeId = @BikeId
	ELSE
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM RecreationalRide
			WHERE YEAR([Date]) = @Year AND BikeId = @BikeId

	
END

GO

