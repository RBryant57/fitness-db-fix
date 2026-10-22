









-- =============================================
-- Author:		YellowCaddis Development
-- Create date: 10/6/06
-- Description:	This procedure will return the maximum
--				training odometer readings for the given year.
--				and given Bike.
-- =============================================
CREATE PROCEDURE [dbo].[GetTrainingMilesByYearByBike] 
		@Year					int = 0,
		@BikeId					int

AS
BEGIN

	SET NOCOUNT ON;

	IF @Year = 0
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM TrainingRide
			WHERE BikeId = @BikeId
	ELSE
		SELECT COALESCE(SUM((EndOdometer - StartOdometer)), 0) FROM TrainingRide
			WHERE YEAR([Date]) = @Year AND BikeId = @BikeId

	
END

GO

